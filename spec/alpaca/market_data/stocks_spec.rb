# frozen_string_literal: true

RSpec.describe Alpaca::MarketData::Stocks do
  let(:client) { Alpaca::MarketData::Client.new(key_id: "KEY", secret_key: "SECRET", feed: :sip) }
  let(:stocks) { client.stocks }

  def bar(close, time)
    {"t" => time, "o" => 1, "h" => 2, "l" => 0.5, "c" => close, "v" => 100, "n" => 3, "vw" => 1.25}
  end

  describe "#bars" do
    it "pages through a multi-symbol request, with one symbol spanning two pages" do
      query = {"symbols" => "AAPL,MSFT", "timeframe" => "1Day", "start" => "2025-01-01", "limit" => "3", "feed" => "sip"}
      stub_json(:get, "#{DATA}/v2/stocks/bars",
        {"bars" => {"AAPL" => [bar(10.5, "2025-01-02T05:00:00Z"), bar(11, "2025-01-03T05:00:00Z")],
                    "MSFT" => [bar(400.25, "2025-01-02T05:00:00Z")]}, "next_page_token" => "page2"},
        query: query)
      stub_json(:get, "#{DATA}/v2/stocks/bars",
        {"bars" => {"MSFT" => [bar(401, "2025-01-03T05:00:00Z")]}, "next_page_token" => nil},
        query: query.merge("page_token" => "page2"))

      bars = stocks.bars(%w[AAPL MSFT], timeframe: "1Day", start: Date.new(2025, 1, 1), limit: 3)
      expect(bars).to be_a(Alpaca::MarketData::Series)
      expect(bars.map(&:symbol)).to eq(%w[AAPL AAPL MSFT MSFT])

      by_symbol = bars.to_h
      expect(by_symbol.keys).to eq(%w[AAPL MSFT])
      expect(by_symbol["MSFT"].map(&:close)).to eq([BigDecimal("400.25"), BigDecimal(401)])
      expect(bars.to_h { |b| [b.timestamp, b.symbol] }.size).to eq(2)
    end

    it "caps with first(n) without fetching further pages" do
      stub_json(:get, "#{DATA}/v2/stocks/bars", openapi_example(:market_data, "/v2/stocks/bars"),
        query: {"symbols" => "AAPL", "timeframe" => "1Hour", "feed" => "sip"})
      expect(stocks.bars(%w[AAPL], timeframe: "1Hour").first(1).size).to eq(1)
    end

    it "uses the single-symbol path for a String and coerces types" do
      example = openapi_example(:market_data, "/v2/stocks/{symbol}/bars").merge("next_page_token" => nil)
      stub_json(:get, "#{DATA}/v2/stocks/AAPL/bars", example,
        query: {"timeframe" => "1Min", "adjustment" => "all", "feed" => "sip"})

      bar = stocks.bars("AAPL", timeframe: "1Min", adjustment: :all).first
      expect(bar).to be_a(Alpaca::MarketData::Bar)
      expect(bar).to have_attributes(symbol: "AAPL", timestamp: Time.utc(2022, 1, 3, 9), open: BigDecimal("178.26"),
        close: BigDecimal("178.21"), low: BigDecimal("178.21"), volume: 1118, trade_count: 65,
        vwap: BigDecimal("178.235733"))
      expect(bar.close).to be_a(BigDecimal)
      expect(bar.volume).to be_a(Integer)
      expect(bar[:c]).to eq(bar.close)
      expect(bar["vw"]).to eq(bar.vwap)
      expect(bar).to be_key(:t)
      expect(bar.to_h).to include(symbol: "AAPL", close: BigDecimal("178.21"))
    end

    it "lets callers override or drop the default feed" do
      stub_json(:get, "#{DATA}/v2/stocks/AAPL/bars", {"bars" => [], "symbol" => "AAPL", "next_page_token" => nil},
        query: {"timeframe" => "1Day", "feed" => "iex"})
      expect(stocks.bars("AAPL", timeframe: "1Day", feed: :iex).to_a).to eq([])

      stub_json(:get, "#{DATA}/v2/stocks/AAPL/bars", {"bars" => nil, "symbol" => "AAPL"}, query: {"timeframe" => "1Day"})
      expect(stocks.bars("AAPL", timeframe: "1Day", feed: nil).to_a).to eq([])
    end

    it "sends no feed when none is configured" do
      plain = Alpaca::MarketData::Client.new(key_id: "KEY", secret_key: "SECRET")
      stub_json(:get, "#{DATA}/v2/stocks/bars", {"bars" => {}, "next_page_token" => nil},
        query: {"symbols" => "AAPL", "timeframe" => "1Day"})
      expect(plain.stocks.bars(["AAPL"], timeframe: "1Day").to_h).to eq({})
    end
  end

  describe "#trades and #quotes" do
    it "returns typed trades" do
      stub_json(:get, "#{DATA}/v2/stocks/trades", openapi_example(:market_data, "/v2/stocks/trades").merge("next_page_token" => nil),
        query: {"symbols" => "AAPL", "start" => "2022-01-03T09:00:00Z", "feed" => "sip"})
      trade = stocks.trades(["AAPL"], start: Time.utc(2022, 1, 3, 9)).first
      expect(trade).to have_attributes(symbol: "AAPL", price: BigDecimal("178.26"), size: 246, exchange: "P",
        id: 1, conditions: ["@", "T"], tape: "C")
      expect(trade.timestamp.nsec).to eq(86_175_744)
    end

    it "returns trades for one symbol" do
      example = openapi_example(:market_data, "/v2/stocks/{symbol}/trades").merge("next_page_token" => nil)
      stub_json(:get, "#{DATA}/v2/stocks/AAPL/trades", example, query: {"feed" => "sip"})
      expect(stocks.trades("AAPL").map(&:id)).to eq([73_833, 73_834])
    end

    it "returns typed quotes" do
      stub_json(:get, "#{DATA}/v2/stocks/quotes", openapi_example(:market_data, "/v2/stocks/quotes").merge("next_page_token" => nil),
        query: {"symbols" => "AAPL", "feed" => "sip"})
      quote = stocks.quotes(%w[AAPL]).to_a.last
      expect(quote).to have_attributes(bid_price: BigDecimal("177.92"), bid_size: 4, ask_price: BigDecimal("178.8"),
        ask_exchange: "Q", conditions: ["R"])

      example = openapi_example(:market_data, "/v2/stocks/{symbol}/quotes").merge("next_page_token" => nil)
      stub_json(:get, "#{DATA}/v2/stocks/AAPL/quotes", example, query: {"feed" => "sip"})
      expect(stocks.quotes("AAPL").first.ask_price).to eq(BigDecimal(0))
    end
  end

  describe "#auctions" do
    it "returns daily auctions without the default feed" do
      stub_json(:get, "#{DATA}/v2/stocks/auctions", openapi_example(:market_data, "/v2/stocks/auctions"),
        query: {"symbols" => "AAPL,TSLA", "limit" => "2"})
      auctions = stocks.auctions(%w[AAPL TSLA], limit: 2).first(3)
      day = auctions.first
      expect(day).to have_attributes(symbol: "AAPL", date: Date.new(2022, 10, 12))
      expect(day.opening.first).to have_attributes(condition: "Q", price: BigDecimal("139.12"), exchange: "P")
      expect(day.closing.size).to eq(4)
      expect(auctions.last.symbol).to eq("TSLA")

      example = openapi_example(:market_data, "/v2/stocks/{symbol}/auctions").merge("next_page_token" => nil)
      stub_json(:get, "#{DATA}/v2/stocks/TSLA/auctions", example)
      expect(stocks.auctions("TSLA").to_h.keys).to eq(["TSLA"])
    end
  end

  describe "latest values" do
    it "returns a Hash for an Array of symbols" do
      stub_json(:get, "#{DATA}/v2/stocks/quotes/latest", openapi_example(:market_data, "/v2/stocks/quotes/latest"),
        query: {"symbols" => "AAPL,TSLA", "feed" => "sip"})
      quotes = stocks.latest_quotes(%w[AAPL TSLA])
      expect(quotes.keys).to eq(%w[AAPL TSLA])
      expect(quotes["TSLA"]).to have_attributes(symbol: "TSLA", bid_price: BigDecimal("911.3"), bid_exchange: "K")

      stub_json(:get, "#{DATA}/v2/stocks/bars/latest", openapi_example(:market_data, "/v2/stocks/bars/latest"),
        query: {"symbols" => "AAPL,TSLA", "feed" => "sip"})
      expect(stocks.latest_bars(%w[AAPL TSLA])["AAPL"].close).to eq(BigDecimal("172.79"))

      stub_json(:get, "#{DATA}/v2/stocks/trades/latest", openapi_example(:market_data, "/v2/stocks/trades/latest"),
        query: {"symbols" => "AAPL", "feed" => "sip"})
      expect(stocks.latest_trades(%w[AAPL])["AAPL"].size).to eq(100)
    end

    it "uses the single-symbol path for a String" do
      stub_json(:get, "#{DATA}/v2/stocks/AAPL/trades/latest", openapi_example(:market_data, "/v2/stocks/{symbol}/trades/latest"),
        query: {"feed" => "delayed_sip"})
      trade = stocks.latest_trades("AAPL", feed: :delayed_sip)
      expect(trade).to have_attributes(symbol: "AAPL", price: BigDecimal("172.6"), id: 689)

      stub_json(:get, "#{DATA}/v2/stocks/AAPL/quotes/latest", openapi_example(:market_data, "/v2/stocks/{symbol}/quotes/latest"),
        query: {"feed" => "sip"})
      expect(stocks.latest_quotes("AAPL").bid_size).to eq(2)

      stub_json(:get, "#{DATA}/v2/stocks/AAPL/bars/latest", openapi_example(:market_data, "/v2/stocks/{symbol}/bars/latest"),
        query: {"feed" => "sip", "currency" => "EUR"})
      expect(stocks.latest_bars("AAPL", currency: "EUR").timestamp).to eq(Time.utc(2022, 8, 17, 9, 7))

      stub_json(:get, "#{DATA}/v2/stocks/ZZZZ/bars/latest", {"symbol" => "ZZZZ"}, query: {"feed" => "sip"})
      expect(stocks.latest_bars("ZZZZ")).to be_nil
    end
  end

  describe "#snapshots" do
    it "returns a Hash of snapshots for an Array" do
      stub_json(:get, "#{DATA}/v2/stocks/snapshots",
        openapi_example(:market_data, "/v2/stocks/snapshots").merge("currency" => "USD"),
        query: {"symbols" => "AAPL,TSLA", "feed" => "sip", "currency" => "USD"})
      snapshots = stocks.snapshots(%w[AAPL TSLA], currency: "USD")
      expect(snapshots.keys).to eq(%w[AAPL TSLA])
      aapl = snapshots["AAPL"]
      expect(aapl.symbol).to eq("AAPL")
      expect(aapl.daily_bar.close).to eq(BigDecimal("173.03"))
      expect(aapl.prev_daily_bar.volume).to eq(54_091_719)
      expect(aapl.latest_trade).to be_a(Alpaca::MarketData::Trade)
      expect(aapl.latest_quote.ask_price).to eq(BigDecimal("172.7"))
      expect(aapl[:minuteBar]).to eq(aapl.minute_bar)
    end

    it "returns one snapshot for a String" do
      stub_json(:get, "#{DATA}/v2/stocks/AAPL/snapshot", openapi_example(:market_data, "/v2/stocks/{symbol}/snapshot"),
        query: {"feed" => "sip"})
      snapshot = stocks.snapshots("AAPL")
      expect(snapshot).to be_a(Alpaca::MarketData::Snapshot)
      expect(snapshot).to have_attributes(symbol: "AAPL")
      expect(snapshot.latest_trade.price).to eq(BigDecimal("172.55"))
    end
  end

  describe "metadata" do
    it "returns exchanges and conditions" do
      stub_json(:get, "#{DATA}/v2/stocks/meta/exchanges", {"Q" => "NASDAQ OMX"})
      expect(stocks.exchanges).to eq("Q" => "NASDAQ OMX")

      stub_json(:get, "#{DATA}/v2/stocks/meta/conditions/trade", {"@" => "Regular Sale"}, query: {"tape" => "C"})
      expect(stocks.conditions(:trade, tape: "C")).to eq("@" => "Regular Sale")
    end
  end
end
