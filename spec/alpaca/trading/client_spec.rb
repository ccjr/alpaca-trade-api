# frozen_string_literal: true

RSpec.describe Alpaca::Trading::Client do
  subject(:client) { trading_client }

  describe "#initialize" do
    it "defaults to paper with API key auth" do
      expect(client.base_url).to eq(PAPER)
      expect(client).to be_paper
      expect(client.connection.auth).to be_a(Alpaca::HTTP::Auth::ApiKey)
      expect(client.inspect).to include(PAPER)
    end

    it "targets live trading" do
      expect(trading_client(paper: false).base_url).to eq("https://api.alpaca.markets")
    end

    it "uses configuration and environment defaults" do
      ENV["APCA_API_KEY_ID"] = "envkey"
      ENV["APCA_API_SECRET_KEY"] = "envsecret"
      Alpaca.reset!
      client = described_class.new
      expect(client.connection.auth.key_id).to eq("envkey")
      expect(Alpaca.trading).to equal(Alpaca.trading)
    end

    it "supports Alpaca Connect OAuth tokens" do
      client = described_class.new(oauth_token: "tok")
      expect(client.connection.auth).to be_a(Alpaca::HTTP::Auth::Bearer)

      Alpaca.configure { |c| c.oauth_token = "configured" }
      expect(described_class.new.connection.auth).to be_a(Alpaca::HTTP::Auth::Bearer)
    end

    it "requires credentials" do
      expect { described_class.new }.to raise_error(Alpaca::ConfigurationError, /APCA_API_KEY_ID/)
    end

    it "accepts a custom base URL" do
      expect(trading_client(base_url: "http://localhost:9999").base_url).to eq("http://localhost:9999")
    end
  end

  describe "#account" do
    it "returns the account with decimals and typed fields" do
      stub_json(:get, "#{PAPER}/v2/account", openapi_example(:trading, "/v2/account"))
      account = client.account
      expect(account).to be_a(Alpaca::Account)
      expect(account.buying_power).to eq(BigDecimal("245432.61"))
      expect(account.last_equity).to eq(BigDecimal("122011.09751111286868"))
      expect(account.status).to eq(:ACTIVE)
      expect(account.balance_asof).to eq(Date.new(2023, 9, 27))
      expect(account.options_trading_level).to eq(2)
      expect(account.shorting_enabled?).to be(true)
      expect(account.crypto_tier).to eq(1)
      expect(account.response.status).to eq(200)
    end
  end

  describe "account configuration" do
    it "reads and updates configuration" do
      stub_json(:get, "#{PAPER}/v2/account/configurations", {"dtbp_check" => "both", "no_shorting" => false,
                                                              "max_margin_multiplier" => "4"})
      expect(client.account_configuration).to have_attributes(dtbp_check: :both, no_shorting: false,
        max_margin_multiplier: BigDecimal(4))

      stub = stub_json(:patch, "#{PAPER}/v2/account/configurations", {"no_shorting" => true},
        request_body: json_body(no_shorting: true, max_options_trading_level: 1))
      expect(client.update_account_configuration(no_shorting: true, max_options_trading_level: 1).no_shorting).to be(true)
      expect(stub).to have_been_requested
    end
  end

  describe "#portfolio_history" do
    it "returns parallel series and zipped points" do
      example = openapi_example(:trading, "/v2/account/portfolio/history", "get", "example-cashflows")
      stub_json(:get, "#{PAPER}/v2/account/portfolio/history", example, query: {"period" => "1W", "timeframe" => "1D"})
      history = client.portfolio_history(period: "1W", timeframe: "1D")
      expect(history.equity.first).to eq(BigDecimal("8425.21"))
      expect(history.base_value_asof).to eq(Date.new(2026, 4, 6))
      expect(history.cashflow).to include("CSD")
      point = history.points.first
      expect(point.time).to eq(Time.at(1_775_606_400).utc)
      expect(point.profit_loss_pct).to eq(BigDecimal("0.0014"))
      expect(history.points.size).to eq(4)
    end
  end

  describe "clocks and calendars" do
    let(:clock) do
      {"market" => {"acronym" => "NYSE", "name" => "New York Stock Exchange", "mic" => "XNYS", "timezone" => "America/New_York"},
       "timestamp" => "2026-10-19T10:00:00-04:00", "is_market_day" => true, "phase" => "core",
       "phase_until" => "2026-10-19T16:00:00-04:00", "next_market_open" => "2026-10-20T09:30:00-04:00",
       "next_market_close" => "2026-10-19T16:00:00-04:00"}
    end

    it "returns the clock for one market" do
      stub_json(:get, "#{PAPER}/v3/clock", {"clocks" => [clock]}, query: {"markets" => "NYSE"})
      result = client.clock
      expect(result.market.mic).to eq("XNYS")
      expect(result).to be_open
      expect(result.next_market_open).to eq(Time.iso8601("2026-10-20T09:30:00-04:00"))
    end

    it "returns clocks for several markets" do
      at = Time.utc(2026, 10, 19, 14)
      stub_json(:get, "#{PAPER}/v3/clock", {"clocks" => [clock, clock]},
        query: {"markets" => "NYSE,NASDAQ", "time" => "2026-10-19T14:00:00Z"})
      expect(client.clocks(markets: %w[NYSE NASDAQ], time: at).size).to eq(2)
    end

    it "returns an empty list when there is no clock data" do
      stub_json(:get, "#{PAPER}/v3/clock", {})
      expect(client.clocks).to eq([])
    end

    it "returns a market calendar" do
      body = {"market" => clock["market"],
              "calendar" => [{"date" => "2026-10-19", "core_start" => "2026-10-19T09:30:00-04:00",
                              "core_end" => "2026-10-19T16:00:00-04:00", "settlement_date" => "2026-10-20"}]}
      stub_json(:get, "#{PAPER}/v3/calendar/NYSE", body, query: {"start" => "2026-10-19", "end" => "2026-10-20"})
      calendar = client.calendar(start: Date.new(2026, 10, 19), end: Date.new(2026, 10, 20))
      expect(calendar).to be_a(Alpaca::MarketCalendar)
      expect(calendar.market.acronym).to eq("NYSE")
      expect(calendar.days.first).to have_attributes(date: Date.new(2026, 10, 19), settlement_date: Date.new(2026, 10, 20))
    end
  end
end
