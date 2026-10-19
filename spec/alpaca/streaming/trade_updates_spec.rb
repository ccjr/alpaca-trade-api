# frozen_string_literal: true

require "alpaca/streaming"

RSpec.describe Alpaca::Streaming::TradeUpdates do
  let(:authorized) { {"stream" => "authorization", "data" => {"status" => "authorized", "action" => "authenticate"}} }
  let(:listening) { {"stream" => "listening", "data" => {"streams" => ["trade_updates"]}} }

  def update(event, id = "o1")
    {"stream" => "trade_updates", "data" => {
      "event" => event, "execution_id" => "e1", "timestamp" => "2026-10-19T14:00:00.5Z", "price" => "180.5", "qty" => "2",
      "position_qty" => "10", "order" => {"id" => id, "symbol" => "AAPL", "status" => event, "filled_qty" => "2"}
    }}
  end

  def stream(transport, **options)
    described_class.new(key_id: "KEY", secret_key: "SECRET", transport: transport, **options)
  end

  before { allow_any_instance_of(described_class).to receive(:sleep) }

  it "authenticates, listens and dispatches typed events" do
    transport = FakeTransport.new([authorized, listening, update("new"), FakeTransport::Raw.new(JSON.generate(update("fill")), true)])
    updates = stream(transport, reconnect: false)
    all = []
    fills = []
    updates.on_update { |event| all << event.event }
    updates.on(:fill, "partial_fill") { |event| fills << event }

    updates.run

    expect(transport.urls).to eq(["wss://paper-api.alpaca.markets/stream"])
    expect(transport.writes).to eq([
      {"action" => "auth", "key" => "KEY", "secret" => "SECRET"},
      {"action" => "listen", "data" => {"streams" => ["trade_updates"]}}
    ])
    expect(all).to eq(%i[new fill])
    fill = fills.first
    expect(fill).to be_a(Alpaca::TradeEvent)
    expect(fill.price).to eq(BigDecimal("180.5"))
    expect(fill.position_qty).to eq(BigDecimal(10))
    expect(fill.order.filled_qty).to eq(BigDecimal(2))
  end

  it "uses the live URL and OAuth authentication" do
    transport = FakeTransport.new([authorized])
    described_class.new(oauth_token: "tok", paper: false, transport: transport, reconnect: false).run
    expect(transport.urls).to eq(["wss://api.alpaca.markets/stream"])
    expect(transport.writes.first).to eq("action" => "authenticate", "data" => {"oauth_token" => "tok"})
  end

  it "raises on rejected credentials without reconnecting" do
    transport = FakeTransport.new([{"stream" => "authorization", "data" => {"status" => "unauthorized"}}], [authorized])
    errors = []
    updates = stream(transport)
    updates.on_error { |e| errors << e }
    expect { updates.run }.to raise_error(Alpaca::Streaming::AuthenticationError, /unauthorized/)
    expect(errors.size).to eq(1)
    expect(transport.connections.size).to eq(1)
  end

  it "reconnects after drops and re-listens" do
    transport = FakeTransport.new(
      [authorized, update("new"), :drop],
      Alpaca::ConnectionError.new("refused"),
      [authorized, update("fill")]
    )
    updates = stream(transport, max_reconnects: 3)
    seen = []
    connects = 0
    disconnects = 0
    errors = []
    updates.on_connect { connects += 1 }
    updates.on_disconnect { disconnects += 1 }
    updates.on_error { |e| errors << e }
    updates.on_update do |event|
      seen << event.event
      updates.stop if seen.size == 2
    end

    updates.run

    expect(seen).to eq(%i[new fill])
    expect(connects).to eq(2)
    expect(disconnects).to eq(3)
    expect(errors.map(&:class)).to eq([Alpaca::ConnectionError])
    expect(transport.writes.count { |w| w["action"] == "listen" }).to eq(2)
  end

  it "gives up after max_reconnects consecutive failures, resetting on success" do
    transport = FakeTransport.new(
      [authorized, :drop],
      Alpaca::ConnectionError.new("1"),
      [authorized, :drop],
      Alpaca::ConnectionError.new("2"),
      Alpaca::ConnectionError.new("3"),
      [authorized]
    )
    stream(transport, max_reconnects: 2).run
    expect(transport.connections.size).to eq(2)
  end

  it "fails when the connection closes during authentication" do
    transport = FakeTransport.new([listening])
    errors = []
    updates = stream(transport, reconnect: false)
    updates.on_error { |e| errors << e }
    updates.run
    expect(errors.first).to be_a(Alpaca::ConnectionError)
  end

  it "reports late authorization failures as errors" do
    transport = FakeTransport.new([authorized, {"stream" => "authorization", "data" => {"status" => "unauthorized"}}])
    errors = []
    updates = stream(transport, reconnect: false)
    updates.on_error { |e| errors << e }
    updates.run
    expect(errors.first).to be_a(Alpaca::Streaming::AuthenticationError)
    expect(updates).not_to be_running
    expect(updates.inspect).to include("paper-api")
  end

  it "requires handler blocks and credentials" do
    expect { stream(FakeTransport.new).on_update }.to raise_error(ArgumentError)
    expect { described_class.new(transport: FakeTransport.new) }.to raise_error(Alpaca::ConfigurationError)
  end
end
