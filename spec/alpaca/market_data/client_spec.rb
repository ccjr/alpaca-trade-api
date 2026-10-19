# frozen_string_literal: true

RSpec.describe Alpaca::MarketData::Client do
  subject(:client) { described_class.new(key_id: "KEY", secret_key: "SECRET") }

  describe "#initialize" do
    it "uses the live host with API key auth" do
      expect(client.base_url).to eq(DATA)
      expect(client).not_to be_sandbox
      expect(client.connection.auth).to be_a(Alpaca::HTTP::Auth::ApiKey)
      expect(client.feed).to be_nil
    end

    it "targets the sandbox host" do
      expect(described_class.new(key_id: "KEY", secret_key: "SECRET", sandbox: true).base_url)
        .to eq("https://data.sandbox.alpaca.markets")
    end

    it "uses configuration and environment defaults" do
      ENV["APCA_API_KEY_ID"] = "envkey"
      ENV["APCA_API_SECRET_KEY"] = "envsecret"
      ENV["APCA_DATA_FEED"] = "sip"
      Alpaca.reset!
      expect(Alpaca.market_data.connection.auth.key_id).to eq("envkey")
      expect(Alpaca.market_data.feed).to eq(:sip)
      expect(Alpaca.market_data).to equal(Alpaca.market_data)
    end

    it "supports Alpaca Connect OAuth tokens" do
      expect(described_class.new(oauth_token: "tok").connection.auth).to be_a(Alpaca::HTTP::Auth::Bearer)

      Alpaca.configure { |c| c.oauth_token = "configured" }
      expect(described_class.new.connection.auth).to be_a(Alpaca::HTTP::Auth::Bearer)
    end

    it "accepts any auth strategy" do
      auth = Alpaca::HTTP::Auth::Basic.new("broker", "secret")
      client = described_class.new(auth: auth, sandbox: true)
      expect(client.connection.auth).to equal(auth)

      stub = stub_request(:get, "https://data.sandbox.alpaca.markets/v2/stocks/meta/exchanges")
        .with(headers: {"Authorization" => "Basic #{["broker:secret"].pack("m0")}"})
        .to_return(status: 200, body: "{}", headers: {"Content-Type" => "application/json"})
      client.stocks.exchanges
      expect(stub).to have_been_requested
    end

    it "requires credentials" do
      expect { described_class.new }.to raise_error(Alpaca::ConfigurationError, /APCA_API_KEY_ID/)
    end

    it "accepts a custom base URL and feed" do
      client = described_class.new(key_id: "KEY", secret_key: "SECRET", base_url: "http://localhost:9999", feed: :iex)
      expect(client.base_url).to eq("http://localhost:9999")
      expect(client.feed).to eq(:iex)
    end
  end

  describe "#logo" do
    it "returns the image bytes" do
      png = "\x89PNG\r\n\x1A\n".b
      stub = stub_request(:get, "#{DATA}/v1beta1/logos/AAPL").with(query: {"placeholder" => "true"})
        .to_return(status: 200, body: png, headers: {"Content-Type" => "image/png"})
      expect(client.logo("AAPL", placeholder: true)).to eq(png)
      expect(stub).to have_been_requested
    end
  end

  describe "#news" do
    it "follows pages and types articles" do
      example = openapi_example(:market_data, "/v1beta1/news")
      stub_json(:get, "#{DATA}/v1beta1/news", example, query: {"symbols" => "AAPL,TSLA", "include_content" => "true"})
      stub_json(:get, "#{DATA}/v1beta1/news", example.merge("next_page_token" => nil),
        query: {"symbols" => "AAPL,TSLA", "include_content" => "true", "page_token" => example["next_page_token"]})

      articles = client.news(symbols: %w[AAPL TSLA], include_content: true).to_a
      expect(articles.size).to eq(2)
      expect(articles.first).to be_a(Alpaca::MarketData::NewsArticle)
      expect(articles.first).to have_attributes(id: 24_843_171, symbols: ["AAPL"], source: "benzinga",
        created_at: Time.utc(2021, 12, 31, 11, 8, 42), images: [])
    end
  end

  describe "#corporate_actions" do
    it "flattens action groups into typed records and follows pages" do
      first = {"corporate_actions" => {
        "cash_dividends" => [{"id" => "d1", "symbol" => "AAPL", "rate" => 0.26, "ex_date" => "2026-11-10",
                              "process_date" => "2026-11-13", "special" => false, "foreign" => false}],
        "forward_splits" => [{"id" => "s1", "symbol" => "NVDA", "new_rate" => 10, "old_rate" => 1}]
      }, "next_page_token" => "abc"}
      second = {"corporate_actions" => {"reorganizations" => [
        {"id" => "r1", "symbol" => "XYZ", "cash_rate" => 1.5,
         "stock_movements" => [{"symbol" => "ABC", "new_rate" => 0.25, "source_rate" => 1}]}
      ]}, "next_page_token" => nil}
      query = {"symbols" => "AAPL,NVDA,XYZ", "types" => "cash_dividend,forward_split,reorganization"}
      stub_json(:get, "#{DATA}/v1/corporate-actions", first, query: query)
      stub_json(:get, "#{DATA}/v1/corporate-actions", second, query: query.merge("page_token" => "abc"))

      actions = client.corporate_actions(symbols: %w[AAPL NVDA XYZ],
        types: %w[cash_dividend forward_split reorganization]).to_a
      expect(actions.map(&:type)).to eq(%i[cash_dividend forward_split reorganization])
      expect(actions[0]).to have_attributes(rate: BigDecimal("0.26"), ex_date: Date.new(2026, 11, 10), special?: false)
      expect(actions[1].new_rate).to eq(BigDecimal(10))
      expect(actions[2].stock_movements.first).to have_attributes(symbol: "ABC", new_rate: BigDecimal("0.25"))
    end

    it "handles an empty response" do
      stub_json(:get, "#{DATA}/v1/corporate-actions", {"corporate_actions" => {}, "next_page_token" => nil})
      expect(client.corporate_actions.to_a).to eq([])
    end
  end

  describe "#screener" do
    it "returns the most active stocks" do
      body = {"most_actives" => [{"symbol" => "NVDA", "volume" => 120_000_000, "trade_count" => 900_000}],
              "last_updated" => "2026-10-19T15:00:00.123456789Z"}
      stub_json(:get, "#{DATA}/v1beta1/screener/stocks/most-actives", body, query: {"by" => "trades", "top" => "5"})
      result = client.screener.most_actives(by: :trades, top: 5)
      expect(result.most_actives.first).to have_attributes(symbol: "NVDA", trade_count: 900_000)
      expect(result.last_updated.nsec).to eq(123_456_789)
    end

    it "returns market movers" do
      stub_json(:get, "#{DATA}/v1beta1/screener/crypto/movers",
        openapi_example(:market_data, "/v1beta1/screener/{market_type}/movers"), query: {"top" => "2"})
      movers = client.screener.movers(:crypto, top: 2)
      expect(movers.market_type).to eq(:stocks)
      expect(movers.gainers.first).to have_attributes(symbol: "AGRI", price: BigDecimal("4.15"),
        percent_change: BigDecimal("145.56"))
      expect(movers.losers.size).to eq(2)
    end
  end

  describe "#fixed_income" do
    let(:isins) { %w[US912797KJ59 US912797KS58 US912797LB15] }

    it "returns latest prices by ISIN" do
      stub_json(:get, "#{DATA}/v1beta1/fixed_income/latest/prices",
        openapi_example(:market_data, "/v1beta1/fixed_income/latest/prices"), query: {"isins" => isins.join(",")})
      prices = client.fixed_income.latest_prices(isins)
      expect(prices.keys).to eq(isins)
      expect(prices["US912797KJ59"]).to have_attributes(isin: "US912797KJ59", price: BigDecimal("99.6459"),
        yield_to_maturity: BigDecimal("4.249"), timestamp: Time.utc(2025, 2, 14, 20, 58, Rational(648, 1000)))
    end

    it "returns one quote for a single ISIN" do
      stub_json(:get, "#{DATA}/v1beta1/fixed_income/latest/quotes",
        openapi_example(:market_data, "/v1beta1/fixed_income/latest/quotes"),
        query: {"isins" => "US912797SX61", "trade_size" => "1000000"})
      quote = client.fixed_income.latest_quotes("US912797SX61", trade_size: 1_000_000)
      expect(quote).to have_attributes(bid_price: BigDecimal("99.81091667"), bid_size: 1_000_000, ask_min_size: 1000,
        ask_yield_to_worst: BigDecimal("2.226923"))
      expect(quote[:bytm]).to eq(BigDecimal("5.236154"))
    end
  end
end
