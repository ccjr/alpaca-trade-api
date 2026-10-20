# frozen_string_literal: true

RSpec.describe Alpaca::Broker::Client do
  let(:token_url) { "https://authx.sandbox.alpaca.markets/v1/oauth2/token" }

  def stub_token(token = "tok", url: token_url)
    stub_request(:post, url).to_return(status: 200, body: JSON.generate(access_token: token, expires_in: 899),
      headers: {"Content-Type" => "application/json"})
  end

  describe "#initialize" do
    it "uses client credentials against the sandbox by default" do
      stub_token
      client = described_class.new(client_id: "cid", client_secret: "cs")
      stub = stub_json(:get, "#{BROKER_SANDBOX}/v1/accounts", [], headers: {}).with(headers: {"Authorization" => "Bearer tok"})
      client.accounts.list
      expect(stub).to have_been_requested
      expect(client).to be_sandbox
      expect(client.base_url).to eq(BROKER_SANDBOX)
    end

    it "targets production hosts" do
      stub_token("live", url: "https://authx.alpaca.markets/v1/oauth2/token")
      client = described_class.new(client_id: "cid", client_secret: "cs", sandbox: false)
      stub_json(:get, "https://broker-api.alpaca.markets/v1/accounts", [])
        .with(headers: {"Authorization" => "Bearer live"})
      expect(client.accounts.list).to eq([])
    end

    it "supports legacy key/secret with HTTP Basic" do
      client = described_class.new(key_id: "k", secret_key: "s")
      expect(client.connection.auth).to be_a(Alpaca::HTTP::Auth::Basic)

      Alpaca.configure do |c|
        c.broker_key_id = "ck"
        c.broker_secret_key = "cs"
      end
      expect(described_class.new.connection.auth).to be_a(Alpaca::HTTP::Auth::Basic)
    end

    it "reads client credentials and private_key_jwt from configuration" do
      Alpaca.configure do |c|
        c.broker_client_id = "cid"
        c.broker_client_secret = "secret"
      end
      expect(Alpaca.broker.connection.auth).to be_a(Alpaca::HTTP::Auth::ClientCredentials)
      expect(described_class.new(client_assertion: -> { "jwt" }).connection.auth)
        .to be_a(Alpaca::HTTP::Auth::ClientCredentials)
    end

    it "requires credentials" do
      expect { described_class.new }.to raise_error(Alpaca::ConfigurationError)
    end
  end

  context "with a client" do
    subject(:client) { described_class.new(key_id: "k", secret_key: "s") }

    it "refreshes an expired token once on 401" do
      stub_request(:post, token_url).to_return(
        {status: 200, body: '{"access_token":"old","expires_in":899}', headers: {"Content-Type" => "application/json"}},
        {status: 200, body: '{"access_token":"new","expires_in":899}', headers: {"Content-Type" => "application/json"}}
      )
      oauth_client = described_class.new(client_id: "cid", client_secret: "cs")
      stub_request(:get, "#{BROKER_SANDBOX}/v1/accounts").with(headers: {"Authorization" => "Bearer old"}).to_return(status: 401)
      stub_json(:get, "#{BROKER_SANDBOX}/v1/accounts", []).with(headers: {"Authorization" => "Bearer new"})
      expect(oauth_client.accounts.list).to eq([])
    end

    describe "#trading" do
      let(:account_id) { "3dcb795c-3ccc-402a-abb9-07e26a1b1326" }
      let(:base) { "#{BROKER_SANDBOX}/v1/trading/accounts/#{account_id}" }
      let(:order) { openapi_example(:broker, "/v1/trading/accounts/{account_id}/orders", "post", "Equity") }

      it "reuses Trading resources under the account scope" do
        acct = client.trading(account_id)
        expect(client.trading(account_id)).to equal(acct)
        expect(acct.inspect).to include(account_id)

        stub_json(:post, "#{base}/orders", order, request_body: json_body(
          symbol: "AAPL", qty: "1", side: "buy", type: "market", time_in_force: "day", client_order_id: "c", commission: "1"
        ))
        expect(acct.orders.create(symbol: "AAPL", qty: "1", side: :buy, type: :market, time_in_force: :day,
          client_order_id: "c", commission: BigDecimal(1))).to be_a(Alpaca::Order)

        stub_json(:get, "#{base}/account", openapi_example(:trading, "/v2/account"))
        expect(acct.account.buying_power).to eq(BigDecimal("245432.61"))

        stub_json(:get, "#{base}/positions", [])
        expect(acct.positions.list).to eq([])

        stub_json(:get, "#{base}/watchlists", [])
        expect(acct.watchlists.list).to eq([])

        stub_json(:patch, "#{base}/account/configurations", {"fractional_trading" => true})
        expect(acct.update_account_configuration(fractional_trading: true).fractional_trading).to be(true)

        stub_json(:get, "#{base}/account/portfolio/history", {"equity" => [1], "timestamp" => [1]})
        expect(acct.portfolio_history.equity).to eq([BigDecimal(1)])

        stub_json(:get, "#{base}/limits", {"daily_limit" => "1000"})
        expect(acct.trading_limits).to eq("daily_limit" => "1000")
      end

      it "pages broker orders by submission time and estimates orders" do
        acct = client.trading(account_id)
        first = order.merge("id" => "o1", "submitted_at" => "2026-10-19T14:00:00Z")
        stub_json(:get, "#{base}/orders", [first], query: {"limit" => "1"})
        stub_json(:get, "#{base}/orders", [], query: {"limit" => "1", "until" => "2026-10-19T14:00:00Z"})
        expect(acct.orders.list(limit: 1).map(&:id)).to eq(%w[o1])

        stub_json(:post, "#{base}/orders/estimation", order, request_body: json_body(symbol: "BTCUSD", notional: "100"))
        expect(acct.orders.estimate(symbol: "BTCUSD", notional: 100.to_s)).to be_a(Alpaca::Order)
      end

      it "exercises with qty and commission" do
        stub = stub_request(:post, "#{base}/positions/AAPL270115C00190000/exercise")
          .with(body: json_body(qty: "1", commission: "0.65")).to_return(status: 200, body: "{}")
        client.trading(account_id).positions.exercise("AAPL270115C00190000", qty: 1.to_s, commission: BigDecimal("0.65"))
        expect(stub).to have_been_requested
      end
    end

    it "builds a Market Data client sharing its credentials" do
      data = client.market_data
      expect(data).to equal(client.market_data)
      expect(client.market_data(feed: :iex)).to equal(client.market_data(feed: :iex))
      expect(client.market_data(feed: :sip)).not_to equal(client.market_data(feed: :iex))
      expect(client.market_data(feed: :sip).feed).to eq(:sip)
      expect(data).to be_sandbox
      stub = stub_json(:get, "https://data.sandbox.alpaca.markets/v1beta1/news", {"news" => [], "next_page_token" => nil})
        .with(headers: {"Authorization" => "Basic azpz"})
      data.news.to_a
      expect(stub).to have_been_requested
    end

    it "exposes reference resources under Broker paths" do
      stub_json(:get, "#{BROKER_SANDBOX}/v1/assets", [{"symbol" => "AAPL", "class" => "us_equity"}])
      expect(client.assets.list.first.asset_class).to eq(:us_equity)

      stub_json(:get, "#{BROKER_SANDBOX}/v1/options/contracts", {"option_contracts" => [], "next_page_token" => nil},
        query: {"limit" => "10000"})
      expect(client.option_contracts.list.to_a).to eq([])

      stub_json(:get, "#{BROKER_SANDBOX}/v1/corporate_actions/announcements", [],
        query: {"ca_types" => "dividend", "since" => "2026-10-01", "until" => "2026-10-31"})
      expect(client.corporate_actions.announcements(ca_types: "dividend", since: "2026-10-01", until: "2026-10-31")).to eq([])

      stub_json(:get, "#{BROKER_SANDBOX}/v2/clock", {"clocks" => [{"phase" => "closed"}]}, query: {"markets" => "NYSE"})
      expect(client.clock.phase).to eq(:closed)

      stub_json(:get, "#{BROKER_SANDBOX}/v2/calendar/NYSE", {"market" => {"acronym" => "NYSE"}, "calendar" => []})
      expect(client.calendar.days).to eq([])
    end

    it "fetches fixed income and entry requirements" do
      stub_json(:get, "#{BROKER_SANDBOX}/v1/assets/entry-requirements", [{"symbol" => "AAPL", "regt_long" => "0.5"}],
        query: {"symbols" => "AAPL"})
      expect(client.assets.entry_requirements("AAPL").first.regt_long).to eq(BigDecimal("0.5"))

      stub_json(:get, "#{BROKER_SANDBOX}/v1/assets/fixed_income/us_treasuries",
        {"us_treasuries" => [{"cusip" => "912797", "coupon" => "4.25", "maturity_date" => "2030-01-15", "subtype" => "note"}]},
        query: {"subtype" => "note"})
      bond = client.assets.us_treasuries(subtype: :note).first
      expect(bond).to have_attributes(coupon: BigDecimal("4.25"), maturity_date: Date.new(2030, 1, 15), subtype: :note)

      stub_json(:get, "#{BROKER_SANDBOX}/v1/assets/fixed_income/us_corporates", {"us_corporates" => []}, query: {"tickers" => "AAPL"})
      expect(client.assets.us_corporates(tickers: "AAPL")).to eq([])
    end

    describe "crypto funding and tokenization for an account" do
      let(:account_id) { "acc-1" }

      it "adds withdrawals to crypto funding" do
        funding = client.crypto_funding(account_id)
        stub_json(:post, "#{BROKER_SANDBOX}/v1/accounts/acc-1/wallets/transfers", {"id" => "t1", "amount" => "1.5"},
          request_body: json_body(amount: "1.5", address: "0xabc", asset: "USDC"))
        expect(funding.withdraw(amount: BigDecimal("1.5"), address: "0xabc", asset: "USDC").amount).to eq(BigDecimal("1.5"))

        stub_json(:get, "#{BROKER_SANDBOX}/v1/wallets/fees/estimate", {"fee" => "0.1"}, query: {"asset" => "USDC"})
        expect(funding.fee_estimate(asset: "USDC").fee).to eq(BigDecimal("0.1"))

        stub_json(:get, "#{BROKER_SANDBOX}/v1/accounts/acc-1/wallets", [{"address" => "0x1"}])
        expect(funding.wallets.first.address).to eq("0x1")
      end

      it "adds issuer callbacks to tokenization" do
        tokenization = client.tokenization(account_id)
        request = {"tokenization_request_id" => "tr1", "status" => "completed"}

        stub_json(:get, "#{BROKER_SANDBOX}/v1/accounts/acc-1/tokenization/requests:by_issuer_request_id", request,
          query: {"issuer_request_id" => "iss-1"})
        expect(tokenization.find_by_issuer_request_id("iss-1").id).to eq("tr1")

        stub_json(:post, "#{BROKER_SANDBOX}/v1/accounts/acc-1/tokenization/callback/mint", request,
          request_body: json_body(tokenization_request_id: "tr1", tx_hash: "0xhash"))
        expect(tokenization.confirm_mint(tokenization_request_id: "tr1", tx_hash: "0xhash").status).to eq(:completed)

        stub = stub_request(:post, "#{BROKER_SANDBOX}/v1/accounts/acc-1/tokenization/callback/redeem")
          .with(headers: {"Idempotency-Key" => "k"}).to_return(status: 200, body: JSON.generate(request),
            headers: {"Content-Type" => "application/json"})
        tokenization.redeem(issuer_request_id: "iss-1", qty: "1", idempotency_key: "k")
        expect(stub).to have_been_requested

        stub_json(:get, "#{BROKER_SANDBOX}/v1/accounts/acc-1/tokenization/requests", [request])
        expect(tokenization.requests.size).to eq(1)
      end
    end
  end
end
