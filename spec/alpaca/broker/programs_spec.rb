# frozen_string_literal: true

RSpec.describe "Broker programs and reference data" do
  let(:client) { Alpaca::Broker::Client.new(key_id: "k", secret_key: "s") }
  let(:account_id) { "acc-1" }

  describe "ACATS" do
    let(:transfer) do
      {"acats_id" => "ac1", "account_id" => account_id, "direction" => "INCOMING", "transfer_type" => "FULL",
       "total_transfer_value" => "1250.75", "status" => {"code" => "PENDING"}}
    end

    it "lists transfers with page_token_next" do
      stub_json(:get, "#{BROKER_SANDBOX}/v1beta1/acats", {"transfers" => [transfer], "page_token_next" => "n2"},
        query: {"transfer_direction" => "INCOMING"})
      stub_json(:get, "#{BROKER_SANDBOX}/v1beta1/acats", {"transfers" => [transfer]},
        query: {"transfer_direction" => "INCOMING", "page_token" => "n2"})
      transfers = client.acats.list(transfer_direction: :INCOMING).to_a
      expect(transfers.map(&:id)).to eq(%w[ac1 ac1])
      expect(transfers.first.total_transfer_value).to eq(BigDecimal("1250.75"))

      stub_json(:get, "#{BROKER_SANDBOX}/v1beta1/acats/#{account_id}", {"transfers" => [transfer]})
      expect(client.acats.list_for_account(account_id).first.direction).to eq(:INCOMING)
    end

    it "creates, finds and inspects transfers" do
      stub_json(:post, "#{BROKER_SANDBOX}/v1beta1/acats/#{account_id}", {"acats_id" => "ac1"}, status: 202,
        request_body: json_body(ip_address: "127.0.0.1", signed_at: "2026-10-19T14:00:00Z",
          contra_account_details: {account_number: "999"}, transfer_details: {transfer_type: "FULL"}))
      expect(client.acats.create(account_id, ip_address: "127.0.0.1", signed_at: Time.utc(2026, 10, 19, 14),
        contra_account_details: {account_number: "999"}, transfer_details: {transfer_type: "FULL"})).to eq("ac1")

      stub_json(:get, "#{BROKER_SANDBOX}/v1beta1/acats/#{account_id}/ac1", transfer)
      expect(client.acats.find(account_id, "ac1").status).to eq("code" => "PENDING")

      stub_json(:get, "#{BROKER_SANDBOX}/v1beta1/acats/#{account_id}/ac1/assets",
        [{"asset_class" => "EQUITY", "symbol" => "AAPL", "qty" => "10"}])
      expect(client.acats.assets(account_id, "ac1").first.qty).to eq(BigDecimal(10))
      stub_json(:get, "#{BROKER_SANDBOX}/v1beta1/acats/#{account_id}/ac1/assets", nil)
      expect(client.acats.assets(account_id, "ac1")).to eq([])

      stub_json(:get, "#{BROKER_SANDBOX}/v1beta1/acats/contrabrokers",
        openapi_example(:broker, "/v1beta1/acats/contrabrokers").then { |ex| ex || {"brokers" => []} })
      expect(client.acats.contra_brokers).to all(be_a(Alpaca::AcatsContraBroker))
      stub_json(:get, "#{BROKER_SANDBOX}/v1beta1/acats/contrabrokers", {})
      expect(client.acats.contra_brokers).to eq([])
    end
  end

  describe "rebalancing" do
    let(:portfolio) { {"id" => "p1", "name" => "Balanced", "status" => "active", "cooldown_days" => 7} }
    let(:run) { {"id" => "r1", "account_id" => account_id, "type" => "full_rebalance", "status" => "QUEUED"} }
    let(:subscription) { {"id" => "s1", "account_id" => account_id, "portfolio_id" => "p1"} }

    it "manages portfolios" do
      portfolios = client.rebalancing.portfolios
      expect(client.rebalancing).to equal(client.rebalancing)

      stub_json(:get, "#{BROKER_SANDBOX}/v1/rebalancing/portfolios", [portfolio], query: {"status" => "active"})
      expect(portfolios.list(status: :active).first.cooldown_days).to eq(7)
      stub_json(:get, "#{BROKER_SANDBOX}/v1/rebalancing/portfolios", nil)
      expect(portfolios.list).to eq([])

      stub_json(:get, "#{BROKER_SANDBOX}/v1/rebalancing/portfolios/p1", portfolio)
      expect(portfolios.find("p1").name).to eq("Balanced")

      weights = [{type: "asset", symbol: "SPY", percent: "60"}, {type: "cash", percent: "40"}]
      stub_json(:post, "#{BROKER_SANDBOX}/v1/rebalancing/portfolios", portfolio,
        request_body: json_body(name: "Balanced", weights: weights, cooldown_days: 7))
      expect(portfolios.create(name: "Balanced", weights: weights, cooldown_days: 7).id).to eq("p1")

      stub_json(:patch, "#{BROKER_SANDBOX}/v1/rebalancing/portfolios/p1", portfolio, request_body: json_body(cooldown_days: 3))
      expect(portfolios.update("p1", cooldown_days: 3).id).to eq("p1")

      stub_request(:delete, "#{BROKER_SANDBOX}/v1/rebalancing/portfolios/p1").to_return(status: 204)
      expect(portfolios.deactivate("p1")).to be(true)
    end

    it "manages subscriptions and runs" do
      subs = client.rebalancing.subscriptions
      stub_json(:get, "#{BROKER_SANDBOX}/v1/rebalancing/subscriptions", {"subscriptions" => [subscription], "next_page_token" => nil})
      expect(subs.list.map(&:id)).to eq(%w[s1])
      stub_json(:get, "#{BROKER_SANDBOX}/v1/rebalancing/subscriptions/s1", subscription)
      expect(subs.find("s1").portfolio_id).to eq("p1")
      stub_json(:post, "#{BROKER_SANDBOX}/v1/rebalancing/subscriptions", subscription,
        request_body: json_body(account_id: account_id, portfolio_id: "p1"))
      expect(subs.create(account_id: account_id, portfolio_id: "p1").id).to eq("s1")
      stub_request(:delete, "#{BROKER_SANDBOX}/v1/rebalancing/subscriptions/s1").to_return(status: 204)
      expect(subs.delete("s1")).to be(true)

      runs = client.rebalancing.runs
      stub_json(:get, "#{BROKER_SANDBOX}/v1/rebalancing/runs", {"runs" => [run], "next_page_token" => nil},
        query: {"account_id" => account_id})
      expect(runs.list(account_id: account_id).first.type).to eq(:full_rebalance)
      stub_json(:get, "#{BROKER_SANDBOX}/v1/rebalancing/runs/r1", run.merge("orders" => [{"id" => "o1"}]))
      expect(runs.find("r1").orders.first).to be_a(Alpaca::Order)
      stub_json(:post, "#{BROKER_SANDBOX}/v1/rebalancing/runs", run,
        request_body: json_body(account_id: account_id, type: "invest_cash", amount: "100"))
      expect(runs.create(account_id: account_id, type: :invest_cash, amount: BigDecimal(100)).id).to eq("r1")
      stub_request(:delete, "#{BROKER_SANDBOX}/v1/rebalancing/runs/r1").to_return(status: 204)
      expect(runs.cancel("r1")).to be(true)
    end
  end

  describe "IPOs" do
    it "lists and finds offerings" do
      list = openapi_example(:broker, "/v1/ipos")
      stub_json(:get, "#{BROKER_SANDBOX}/v1/ipos", list.merge("next_page_token" => nil), query: {"availability" => "available"})
      offerings = client.ipos.list(availability: :available).to_a
      expect(offerings).to all(be_a(Alpaca::IPOOffering))
      expect(offerings.size).to eq(list["data"].size)

      single = openapi_example(:broker, "/v1/ipos/{offering_reference}")
      stub_json(:get, "#{BROKER_SANDBOX}/v1/ipos/ref-1", single)
      expect(client.ipos.find("ref-1").ipo_reference).to eq(single["data"]["ipo_reference"])
    end
  end

  describe "FPSL" do
    it "lists loans, tiers and analytics" do
      stub_json(:get, "#{BROKER_SANDBOX}/v1/fpsl/loans", {"loans" => [{"symbol" => "AAPL", "quantity" => 10,
                                                                       "market_value" => "2000.5"}], "next_page_token" => nil},
        query: {"account_id" => account_id})
      expect(client.fpsl.loans(account_id: account_id).first.market_value).to eq(BigDecimal("2000.5"))

      stub_json(:get, "#{BROKER_SANDBOX}/v1/fpsl/tiers", [{"id" => "t1", "customer_split" => "0.5"}])
      expect(client.fpsl.tiers.first.customer_split).to eq(BigDecimal("0.5"))
      stub_json(:get, "#{BROKER_SANDBOX}/v1/fpsl/tiers", nil)
      expect(client.fpsl.tiers).to eq([])

      stub_json(:get, "#{BROKER_SANDBOX}/v1/fpsl/analytics/#{account_id}/loans", {"total_lending_activities" => 2},
        query: {"start" => "2026-10-01"})
      expect(client.fpsl.analytics(account_id, start: Date.new(2026, 10, 1))).to eq("total_lending_activities" => 2)
    end
  end

  describe "reporting" do
    it "returns aggregate positions, EOD positions and cash interest" do
      stub_json(:get, "#{BROKER_SANDBOX}/v1/reporting/eod/aggregate_positions",
        [{"symbol" => "AAPL", "long_qty" => "100", "num_accounts" => 3}], query: {"date" => "2026-10-18"})
      expect(client.reporting.aggregate_positions(date: Date.new(2026, 10, 18)).first.long_qty).to eq(BigDecimal(100))
      stub_json(:get, "#{BROKER_SANDBOX}/v1/reporting/eod/aggregate_positions", nil, query: {"date" => "2026-10-18"})
      expect(client.reporting.aggregate_positions(date: "2026-10-18")).to eq([])

      stub_json(:get, "#{BROKER_SANDBOX}/v1/reporting/eod/positions",
        {"asof" => "2026-10-18", "positions" => {"a1" => [{"symbol" => "AAPL", "qty" => "1"}]}, "next_page_token" => "p2"},
        query: {"asof" => "2026-10-18"})
      stub_json(:get, "#{BROKER_SANDBOX}/v1/reporting/eod/positions", {"positions" => {"a2" => [{"symbol" => "MSFT"}]}},
        query: {"asof" => "2026-10-18", "page_token" => "p2"})
      expect(client.reporting.positions(asof: "2026-10-18").map(&:account_id)).to eq(%w[a1 a2])

      stub_json(:get, "#{BROKER_SANDBOX}/v1/reporting/eod/cash_interest",
        {"interest" => [{"account_id" => account_id, "cash_balance" => "1000", "date" => "2026-10-18"}], "next_page_token" => nil})
      expect(client.reporting.cash_interest.first.cash_balance).to eq(BigDecimal(1000))
    end
  end

  describe "reference data and OAuth" do
    it "lists APR tiers, country info and logos" do
      stub_json(:get, "#{BROKER_SANDBOX}/v1/cash_interest/apr_tiers", {"apr_tiers" => [{"id" => "t1", "account_rate_bps" => 350}]})
      expect(client.apr_tiers.first.account_rate_bps).to eq(350)
      stub_json(:get, "#{BROKER_SANDBOX}/v1/cash_interest/apr_tiers", {})
      expect(client.apr_tiers).to eq([])

      stub_json(:get, "#{BROKER_SANDBOX}/v1/country-info", {"USA" => {"full_name" => "United States",
                                                                      "securities_risk_rating" => "low"}})
      expect(client.country_info["USA"].securities_risk_rating).to eq(:low)
      stub_json(:get, "#{BROKER_SANDBOX}/v1/country-info", nil)
      expect(client.country_info).to eq({})

      stub_request(:get, "#{BROKER_SANDBOX}/v1beta1/logos/AAPL").with(query: {"placeholder" => "false"})
        .to_return(status: 200, body: "\x89PNG".b, headers: {"Content-Type" => "image/png"})
      expect(client.logo("AAPL", placeholder: false)).to start_with("\x89PNG".b)
    end

    it "creates agreements" do
      stub_json(:post, "#{BROKER_SANDBOX}/v1/agreements", {"agreement" => "options_agreement", "account_id" => account_id},
        status: 201)
      expect(client.create_agreement(agreement: :options_agreement, account_id: account_id, signed_at: Time.now,
        ip_address: "127.0.0.1").agreement).to eq(:options_agreement)
    end

    it "drives OAuth" do
      stub_json(:get, "#{BROKER_SANDBOX}/v1/oauth/clients/c1", {"client_id" => "c1", "redirect_uri" => ["http://x"]},
        query: {"response_type" => "code"})
      expect(client.oauth.find_client("c1", response_type: :code).redirect_uri).to eq(["http://x"])

      params = {account_id: account_id, client_id: "c1", client_secret: "s", redirect_uri: "http://x", scope: "general"}
      stub_json(:post, "#{BROKER_SANDBOX}/v1/oauth/authorize", {"code" => "abc"}, request_body: json_body(params))
      expect(client.oauth.authorize(**params).code).to eq("abc")

      stub_json(:post, "#{BROKER_SANDBOX}/v1/oauth/token", {"access_token" => "tok", "token_type" => "Bearer"},
        request_body: json_body(params))
      expect(client.oauth.issue_token(**params).access_token).to eq("tok")
    end
  end
end
