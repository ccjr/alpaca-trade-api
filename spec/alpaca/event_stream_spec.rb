# frozen_string_literal: true

RSpec.describe Alpaca::EventStream do
  let(:broker) { Alpaca::Broker::Client.new(key_id: "k", secret_key: "s") }
  let(:trades_url) { "#{BROKER_SANDBOX}/v2/events/trades" }

  def sse(*payloads)
    payloads.map { |payload| payload.is_a?(String) ? payload : "data: #{JSON.generate(payload)}\n\n" }.join
  end

  def trade(id, event = "fill")
    {"event_id" => id, "account_id" => "acc", "at" => "2026-10-19T14:00:00Z", "event" => event, "price" => 10.25,
     "qty" => "2", "position_qty" => "5", "timestamp" => "2026-10-19T14:00:00.123Z",
     "order" => {"id" => "o1", "symbol" => "AAPL", "status" => "filled", "filled_qty" => "2"}}
  end

  before { allow_any_instance_of(described_class).to receive(:sleep) }

  describe Alpaca::SSE::Parser do
    it "parses messages across chunk boundaries, ignoring comments" do
      parser = described_class.new
      messages = []
      ["id: 1\nevent: tra", "de\ndata: {\"a\":", "1}\n\n:heartbeat\n\n", "data: line1\r\ndata: line2\n\n", "data: x"].each do |chunk|
        parser.feed(chunk) { |message| messages << message }
      end
      expect(messages).to eq([
        Alpaca::SSE::Message.new(id: "1", event: "trade", data: '{"a":1}'),
        Alpaca::SSE::Message.new(id: nil, event: nil, data: "line1\nline2")
      ])
    end
  end

  it "replays a bounded window and stops" do
    stub_request(:get, trades_url)
      .with(query: {"since" => "2026-10-19", "until" => "2026-10-20"}, headers: {"Accept" => "text/event-stream"})
      .to_return(status: 200, body: sse(trade("01A"), ":heartbeat\n\n", [trade("01B", "partial_fill"), trade("01C")]),
        headers: {"Content-Type" => "text/event-stream"})

    events = broker.events.trades(since: Date.new(2026, 10, 19), until: Date.new(2026, 10, 20)).to_a

    expect(events.map(&:event_id)).to eq(%w[01A 01B 01C])
    event = events.first
    expect(event).to be_a(Alpaca::TradeEvent)
    expect(event).to be_fill
    expect(event.price).to eq(BigDecimal("10.25"))
    expect(event.position_qty).to eq(BigDecimal(5))
    expect(event.order.filled_qty).to eq(BigDecimal(2))
    expect(event.timestamp).to eq(Time.utc(2026, 10, 19, 14, 0, Rational(123, 1000)))
  end

  it "reconnects unbounded streams and resumes after the last event id" do
    stub_request(:get, trades_url).with(query: {"since" => "2026-10-19"}).to_return(status: 200, body: sse(trade("01A")))
    stub_request(:get, trades_url).with(query: {"since_id" => "01A"})
      .to_raise(Faraday::ConnectionFailed.new("reset")).then
      .to_return(status: 200, body: sse(trade("01B")))

    expect(broker.events.trades(since: "2026-10-19").first(2).map(&:event_id)).to eq(%w[01A 01B])
  end

  it "resumes legacy streams with since_ulid" do
    url = "#{BROKER_SANDBOX}/v1/events/accounts/status"
    stub_request(:get, url).to_return(status: 200,
      body: sse({"event_id" => 7, "event_ulid" => "01U", "account_id" => "a", "status_from" => "SUBMITTED",
                 "status_to" => "APPROVED"}))
    stub_request(:get, url).with(query: {"since_ulid" => "01U"}).to_return(status: 200,
      body: sse({"event_id" => 8, "event_ulid" => "01V", "status_to" => "ACTIVE"}))

    events = broker.events.account_status.first(2)
    expect(events.map(&:status_to)).to eq(%i[APPROVED ACTIVE])
    expect(events.first).to be_a(Alpaca::AccountStatusEvent)
  end

  it "gives up after max_reconnects and raises API errors" do
    stub_request(:get, trades_url).with(query: hash_including({})).to_raise(Faraday::ConnectionFailed.new("down"))
    stream = described_class.new(broker.connection, "/v2/events/trades", model: Alpaca::TradeEvent, max_reconnects: 2)
    expect { stream.to_a }.to raise_error(Alpaca::ConnectionError)

    stub_request(:get, trades_url).with(query: hash_including({})).to_return(status: 403, body: '{"message":"forbidden"}',
      headers: {"Content-Type" => "application/json"})
    expect { broker.events.trades(until: "2026-10-20").to_a }.to raise_error(Alpaca::ForbiddenError, /forbidden/)
  end

  it "stops reconnecting at max_reconnects when the server keeps closing" do
    stub = stub_request(:get, trades_url).to_return(status: 200, body: "")
    stream = described_class.new(broker.connection, "/v2/events/trades", max_reconnects: 2)
    expect(stream.to_a).to eq([])
    expect(stub).to have_been_requested.times(3)
    expect(stream).to be_reconnect
    expect(stream.inspect).to include("/v2/events/trades")
  end

  it "skips malformed payloads and builds generic events" do
    stub_request(:get, "#{BROKER_SANDBOX}/v2/events/system").with(query: {"until" => "x"})
      .to_return(status: 200, body: "data: not json\n\n" + sse({"event_id" => "01S", "type" => "market_open"}))
    events = broker.events.system(until: "x").to_a
    expect(events.map { |e| e[:type] }).to eq(["market_open"])
    expect(events.first).to be_a(Alpaca::Event)
  end

  it "fetches a single activity event" do
    stub_request(:get, "#{BROKER_SANDBOX}/v2beta1/accounts/acc/events/activities/01E")
      .to_return(status: 200, body: sse({"event_id" => "01E", "activity_type" => "FILL", "qty" => "3"}))
    event = broker.events.activity("acc", "01E")
    expect(event).to be_a(Alpaca::ActivityEvent)
    expect(event.qty).to eq(BigDecimal(3))
  end

  it "exposes every broker stream" do
    {
      activities: ["/v2beta1/events/activities", Alpaca::ActivityEvent],
      journals: ["/v2/events/journals/status", Alpaca::JournalEvent],
      funding: ["/v2/events/funding/status", Alpaca::FundingEvent],
      admin_actions: ["/v2/events/admin-actions", Alpaca::Event],
      ipos: ["/v2/events/ipos", Alpaca::Event],
      legacy_journals: ["/v1/events/journals/status", Alpaca::JournalEvent],
      transfers: ["/v1/events/transfers/status", Alpaca::TransferEvent],
      non_trade_activities: ["/v1/events/nta", Alpaca::NonTradeActivityEvent]
    }.each do |method, (path, model)|
      stub_request(:get, "#{BROKER_SANDBOX}#{path}").with(query: {"until" => "2026-10-20"})
        .to_return(status: 200, body: sse({"event_id" => "1"}))
      expect(broker.events.public_send(method, until: "2026-10-20").to_a.first).to be_a(model)
    end
  end

  it "streams Trading API account activities" do
    stub_request(:get, "#{PAPER}/v2beta1/events/activities").with(query: {"since" => "2026-10-19T00:00:00Z", "until" => "2026-10-19T01:00:00Z"})
      .to_return(status: 200, body: sse({"event_id" => "01T", "activity_type" => "DIV", "net_amount" => "1.5"}))
    events = trading_client.events.activities(since: Time.utc(2026, 10, 19), until: Time.utc(2026, 10, 19, 1)).to_a
    expect(events.first.net_amount).to eq(BigDecimal("1.5"))
  end

  it "re-authenticates a stream once on 401" do
    stub_request(:post, "https://authx.sandbox.alpaca.markets/v1/oauth2/token").to_return(
      {status: 200, body: '{"access_token":"old","expires_in":899}', headers: {"Content-Type" => "application/json"}},
      {status: 200, body: '{"access_token":"new","expires_in":899}', headers: {"Content-Type" => "application/json"}}
    )
    client = Alpaca::Broker::Client.new(client_id: "c", client_secret: "s")
    stub_request(:get, trades_url).with(query: hash_including({}), headers: {"Authorization" => "Bearer old"}).to_return(status: 401, body: "")
    stub_request(:get, trades_url).with(query: hash_including({}), headers: {"Authorization" => "Bearer new"}).to_return(status: 200, body: sse(trade("01A")))
    expect(client.events.trades(until: "2026-10-20").to_a.size).to eq(1)

    stub_request(:get, trades_url).with(query: hash_including({})).to_return(status: 401, body: "")
    expect { client.events.trades(until: "2026-10-20").to_a }.to raise_error(Alpaca::AuthenticationError)
  end

  it "maps stream timeouts to TimeoutError" do
    stub_request(:get, trades_url).with(query: hash_including({})).to_raise(Faraday::TimeoutError)
    expect { broker.events.trades(until: "x").to_a }.to raise_error(Alpaca::TimeoutError)
  end
end
