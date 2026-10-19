# frozen_string_literal: true

require "alpaca/streaming"
require "msgpack"

RSpec.describe Alpaca::Streaming::MarketData do
  let(:connected) { [{"T" => "success", "msg" => "connected"}] }
  let(:authenticated) { [{"T" => "success", "msg" => "authenticated"}] }

  def credentials = {key_id: "KEY", secret_key: "SECRET"}

  before { allow_any_instance_of(described_class).to receive(:sleep) }

  describe ".stocks" do
    it "authenticates, subscribes from handlers and dispatches typed records" do
      transport = FakeTransport.new([
        connected, authenticated,
        [{"T" => "subscription", "trades" => ["AAPL"], "quotes" => ["*"], "bars" => []}],
        [{"T" => "t", "S" => "AAPL", "i" => 1, "x" => "V", "p" => 180.25, "s" => 100, "c" => ["@"],
          "t" => "2026-10-19T14:00:00.123456789Z", "z" => "C"},
          {"T" => "t", "S" => "MSFT", "p" => 400.0, "s" => 5, "t" => "2026-10-19T14:00:00Z"},
          {"T" => "q", "S" => "MSFT", "bp" => 399.9, "bs" => 2, "ap" => 400.1, "as" => 3, "t" => "2026-10-19T14:00:00Z"}],
        [{"T" => "s", "S" => "AAPL", "sc" => "H", "sm" => "Trading Halt", "rc" => "T12", "t" => "2026-10-19T14:00:01Z"},
          {"T" => "l", "S" => "AAPL", "u" => 190.5, "d" => 170.5, "i" => "B", "t" => "2026-10-19T14:00:01Z"},
          {"T" => "c", "S" => "AAPL", "oi" => 1, "op" => 180.25, "ci" => 2, "cp" => 180.3, "t" => "2026-10-19T14:00:02Z"},
          {"T" => "x", "S" => "AAPL", "i" => 2, "a" => "C", "p" => 180.3, "t" => "2026-10-19T14:00:03Z"},
          {"T" => "i", "S" => "AAPL", "p" => 181, "t" => "2026-10-19T15:50:00Z"},
          {"T" => "zz"}]
      ])
      stream = described_class.stocks(feed: :sip, transport: transport, reconnect: false, **credentials)
      trades = []
      quotes = []
      other = []
      subscriptions = []
      stream.on_trade("AAPL") { |trade| trades << trade }
      stream.on_quote("*") { |quote| quotes << quote }
      stream.on_status { |s| other << s }
      stream.on_luld { |l| other << l }
      stream.on_correction { |c| other << c }
      stream.on_cancel_error { |x| other << x }
      stream.on_imbalance("AAPL") { |i| other << i }
      stream.on_subscription { |s| subscriptions << s }

      stream.run

      expect(transport.urls).to eq(["wss://stream.data.alpaca.markets/v2/sip"])
      expect(transport.writes).to eq([
        {"action" => "auth", "key" => "KEY", "secret" => "SECRET"},
        {"action" => "subscribe", "trades" => ["AAPL"], "quotes" => ["*"], "imbalances" => ["AAPL"]}
      ])
      expect(trades.size).to eq(1)
      expect(trades.first).to have_attributes(symbol: "AAPL", price: BigDecimal("180.25"), size: 100, exchange: "V")
      expect(trades.first.timestamp.nsec).to eq(123_456_789)
      expect(quotes.first).to have_attributes(symbol: "MSFT", bid_price: BigDecimal("399.9"), ask_size: 3)
      expect(other.map(&:class)).to eq([
        Alpaca::MarketData::TradingStatus, Alpaca::MarketData::LULD, Alpaca::MarketData::TradeCorrection,
        Alpaca::MarketData::TradeCancel, Alpaca::MarketData::Imbalance
      ])
      expect(other[1].limit_up_price).to eq(BigDecimal("190.5"))
      expect(other[2].corrected_price).to eq(BigDecimal("180.3"))
      expect(subscriptions.first).to include("trades" => ["AAPL"])
    end

    it "changes subscriptions while running and resubscribes after reconnecting" do
      transport = FakeTransport.new(
        [connected, authenticated, [{"T" => "b", "S" => "AAPL", "c" => 1, "t" => "2026-10-19T14:00:00Z"}], :drop],
        [connected, authenticated, [{"T" => "b", "S" => "NVDA", "c" => 2, "t" => "2026-10-19T14:01:00Z"}]]
      )
      stream = described_class.stocks(transport: transport, max_reconnects: 2, **credentials)
      bars = []
      stream.on_bar do |bar|
        bars << bar.symbol
        if bars.size == 1
          stream.subscribe(bars: %w[NVDA]).unsubscribe(bars: %w[AAPL])
        else
          stream.stop
        end
      end
      stream.subscribe(bars: %w[AAPL])

      stream.run

      expect(transport.urls.first).to eq("wss://stream.data.alpaca.markets/v2/iex")
      expect(bars).to eq(%w[AAPL NVDA])
      expect(transport.connections.first.writes).to include(
        {"action" => "subscribe", "bars" => ["NVDA"]}, {"action" => "unsubscribe", "bars" => ["AAPL"]}
      )
      expect(transport.connections.last.writes.last).to eq("action" => "subscribe", "bars" => ["NVDA"])
      expect(stream.subscriptions).to eq("bars" => ["NVDA"])
    end

    it "raises on bad credentials and connection limits without reconnecting" do
      transport = FakeTransport.new([connected, [{"T" => "error", "code" => 402, "msg" => "auth failed"}]])
      expect { described_class.stocks(transport: transport, **credentials).run }
        .to raise_error(Alpaca::Streaming::AuthenticationError, /auth failed/)

      transport = FakeTransport.new([connected, [{"T" => "error", "code" => 406, "msg" => "connection limit exceeded"}]])
      expect { described_class.stocks(transport: transport, **credentials).run }
        .to raise_error(Alpaca::Streaming::ConnectionLimitError, /406/)
    end

    it "reports subscription errors without disconnecting" do
      transport = FakeTransport.new([connected, authenticated, [{"T" => "error", "code" => 405, "msg" => "symbol limit exceeded"}]])
      errors = []
      stream = described_class.stocks(transport: transport, reconnect: false, **credentials)
      stream.on_error { |e| errors << e }
      stream.run
      expect(errors.first).to be_a(Alpaca::Streaming::StreamError)
      expect(errors.first.code).to eq(405)
    end

    it "fails when the connection closes before authenticating" do
      errors = []
      stream = described_class.stocks(transport: FakeTransport.new([connected]), reconnect: false, **credentials)
      stream.on_error { |e| errors << e }
      stream.run
      expect(errors.first).to be_a(Alpaca::ConnectionError)
    end

    it "validates handlers and channels" do
      stream = described_class.stocks(transport: FakeTransport.new, **credentials)
      expect { stream.on_orderbook("AAPL") { nil } }.to raise_error(ArgumentError, /not available/)
      expect { stream.on_trade("AAPL") }.to raise_error(ArgumentError, /block/)
      expect { stream.subscribe(nope: ["AAPL"]) }.to raise_error(ArgumentError, /unknown channel/)
    end
  end

  describe "other feeds" do
    it "streams crypto orderbooks" do
      transport = FakeTransport.new([connected, authenticated,
        [{"T" => "o", "S" => "BTC/USD", "t" => "2026-10-19T14:00:00Z", "r" => true,
          "b" => [{"p" => 65_000.5, "s" => 0.25}], "a" => [{"p" => 65_001, "s" => 1.5}]}]])
      books = []
      stream = described_class.crypto(transport: transport, reconnect: false, **credentials)
      stream.on_orderbook("BTC/USD") { |book| books << book }
      stream.run
      expect(transport.urls).to eq(["wss://stream.data.alpaca.markets/v1beta3/crypto/us"])
      expect(books.first).to be_reset
      expect(books.first.bids.first.size).to eq(BigDecimal("0.25"))
    end

    it "streams news filtered by symbols" do
      article = {"T" => "n", "id" => 1, "headline" => "Up", "symbols" => %w[AAPL], "created_at" => "2026-10-19T14:00:00Z"}
      transport = FakeTransport.new([connected, authenticated, [article, article.merge("symbols" => %w[TSLA])]])
      news = []
      stream = described_class.news(transport: transport, reconnect: false, sandbox: true, oauth_token: "tok")
      stream.on_news("AAPL") { |a| news << a }
      stream.run
      expect(transport.urls).to eq(["wss://stream.data.sandbox.alpaca.markets/v1beta1/news"])
      expect(transport.writes.first).to eq("action" => "auth", "key" => "oauth", "secret" => "tok")
      expect(news.map(&:headline)).to eq(["Up"])
    end

    it "uses msgpack for options" do
      factory = MessagePack::Factory.new
      factory.register_type(-1, Time, packer: MessagePack::Time::Packer, unpacker: MessagePack::Time::Unpacker)
      at = Time.utc(2026, 10, 19, 14, 0, 0, 500)
      frames = [
        FakeTransport::Raw.new(factory.dump([{"T" => "success", "msg" => "connected"}]), true),
        FakeTransport::Raw.new(factory.dump([{"T" => "success", "msg" => "authenticated"}]), true),
        FakeTransport::Raw.new(factory.dump([{"T" => "q", "S" => "AAPL270115C00190000", "bp" => 1.25, "bs" => 10,
                                              "ap" => 1.3, "as" => 5, "t" => at, "c" => "A"}]), true)
      ]
      transport = Class.new(FakeTransport) do
        def connect(url, headers: {})
          super { |socket| yield socket.tap { |s| s.define_singleton_method(:write) { |payload, binary: false| writes << [payload, binary] } } }
        end
      end.new(frames)
      quotes = []
      stream = described_class.options(feed: :opra, transport: transport, reconnect: false, **credentials)
      stream.on_quote("AAPL270115C00190000") { |q| quotes << q }
      stream.run

      expect(transport.urls).to eq(["wss://stream.data.alpaca.markets/v1beta1/opra"])
      expect(transport.headers.first).to eq("Content-Type" => "application/msgpack")
      payload, binary = transport.writes.last
      expect(binary).to be(true)
      expect(factory.load(payload)).to eq("action" => "subscribe", "quotes" => ["AAPL270115C00190000"])
      expect(quotes.first).to have_attributes(bid_price: BigDecimal("1.25"), condition: "A", timestamp: at)
    end

    it "explains a missing msgpack dependency" do
      allow_any_instance_of(Alpaca::Streaming::MsgpackCodec).to receive(:require).and_raise(LoadError, "msgpack")
      expect { described_class.options(transport: FakeTransport.new, **credentials) }
        .to raise_error(Alpaca::MissingDependencyError, /msgpack/)
    end

    it "connects to the always-on test feed with a broker token" do
      auth = Alpaca::HTTP::Auth::Basic.new("bk", "bs")
      transport = FakeTransport.new([connected, authenticated])
      described_class.test(transport: transport, reconnect: false, auth: auth).run
      expect(transport.urls).to eq(["wss://stream.data.alpaca.markets/v2/test"])
      expect(transport.writes.first).to eq("action" => "auth", "key" => "bk", "secret" => "bs")
    end
  end
end
