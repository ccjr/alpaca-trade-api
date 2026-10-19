# frozen_string_literal: true

RSpec.describe "Trading reference data" do
  let(:client) { trading_client }

  describe Alpaca::Trading::Activities do
    let(:fill) do
      {"id" => "20260101093000000::a", "activity_type" => "FILL", "transaction_time" => "2026-01-01T14:30:00Z",
       "type" => "fill", "price" => "10.5", "qty" => "2", "side" => "buy", "symbol" => "AAPL", "order_id" => "o1"}
    end
    let(:dividend) do
      {"id" => "20260102000000000::b", "activity_type" => "DIV", "date" => "2026-01-02", "net_amount" => "1.23",
       "symbol" => "AAPL", "per_share_amount" => "0.24", "status" => "executed"}
    end

    it "pages with the last activity id" do
      stub_json(:get, "#{PAPER}/v2/account/activities", [fill, dividend],
        query: {"page_size" => "2", "activity_types" => "FILL,DIV"})
      stub_json(:get, "#{PAPER}/v2/account/activities", [],
        query: {"page_size" => "2", "activity_types" => "FILL,DIV", "page_token" => "20260102000000000::b"})

      activities = client.activities.list(activity_types: %w[FILL DIV], page_size: 2).to_a
      expect(activities.map(&:trade?)).to eq([true, false])
      expect(activities.first).to have_attributes(price: BigDecimal("10.5"), side: :buy)
      expect(activities.last.net_amount).to eq(BigDecimal("1.23"))
    end

    it "lists one activity type through its own endpoint" do
      stub_json(:get, "#{PAPER}/v2/account/activities/DIV", [dividend], query: {"page_size" => "100", "date" => "2026-01-02"})
      expect(client.activities.list("DIV", date: Date.new(2026, 1, 2)).to_a.size).to eq(1)
    end
  end

  describe Alpaca::Trading::Assets do
    let(:asset) do
      {"id" => "a1", "class" => "us_equity", "exchange" => "NASDAQ", "symbol" => "AAPL", "name" => "Apple",
       "status" => "active", "tradable" => true, "fractionable" => true, "attributes" => ["has_options"],
       "min_trade_increment" => "0.000000001", "margin_requirement_long" => "30"}
    end

    it "lists and finds assets" do
      stub_json(:get, "#{PAPER}/v2/assets", [asset], query: {"status" => "active", "attributes" => "has_options"})
      result = client.assets.list(status: :active, attributes: %w[has_options]).first
      expect(result).to have_attributes(asset_class: :us_equity, tradable: true, attributes: ["has_options"],
        min_trade_increment: BigDecimal("0.000000001"))

      stub_json(:get, "#{PAPER}/v2/assets/AAPL", asset)
      expect(client.assets.find("AAPL").name).to eq("Apple")

      stub_json(:get, "#{PAPER}/v2/assets", nil)
      expect(client.assets.list).to eq([])
    end
  end

  describe Alpaca::Trading::OptionContracts do
    let(:contract) do
      {"id" => "c1", "symbol" => "AAPL240119C00100000", "name" => "AAPL Jan 19 2024 100 Call", "status" => "active",
       "tradable" => true, "expiration_date" => "2024-01-19", "root_symbol" => "AAPL", "underlying_symbol" => "AAPL",
       "underlying_asset_id" => "u1", "type" => "call", "style" => "american", "strike_price" => "100",
       "multiplier" => "100", "size" => "100", "open_interest" => "6168", "open_interest_date" => "2024-01-12",
       "close_price" => "85.81", "close_price_date" => "2024-01-12", "ppind" => true,
       "deliverables" => [{"type" => "equity", "symbol" => "AAPL", "amount" => "100", "allocation_percentage" => "100",
                           "settlement_type" => "T+1", "settlement_method" => "CCC", "delayed_settlement" => false}]}
    end

    it "follows next_page_token" do
      base = {"underlying_symbols" => "AAPL", "type" => "call", "limit" => "10000"}
      stub_json(:get, "#{PAPER}/v2/options/contracts", {"option_contracts" => [contract], "next_page_token" => "MTAw"},
        query: base)
      stub_json(:get, "#{PAPER}/v2/options/contracts", {"option_contracts" => [contract], "next_page_token" => nil},
        query: base.merge("page_token" => "MTAw"))

      contracts = client.option_contracts.list(underlying_symbols: %w[AAPL], type: :call).to_a
      expect(contracts.size).to eq(2)
      expect(contracts.first).to have_attributes(strike_price: BigDecimal(100), type: :call,
        expiration_date: Date.new(2024, 1, 19))
      expect(contracts.first.deliverables.first.settlement_type).to eq("T+1")
    end

    it "finds a contract" do
      stub_json(:get, "#{PAPER}/v2/options/contracts/AAPL240119C00100000", contract)
      expect(client.option_contracts.find("AAPL240119C00100000").id).to eq("c1")
    end
  end

  describe Alpaca::Trading::CorporateActions do
    it "lists and finds announcements" do
      announcement = {"id" => "ca1", "ca_type" => "dividend", "ca_sub_type" => "cash", "initiating_symbol" => "AAPL",
                      "ex_date" => "2026-11-10", "cash" => "0.26"}
      stub_json(:get, "#{PAPER}/v2/corporate_actions/announcements", [announcement],
        query: {"ca_types" => "dividend", "since" => "2026-10-01", "until" => "2026-11-30"})
      result = client.corporate_actions.announcements(ca_types: %w[dividend], since: Date.new(2026, 10, 1),
        until: Date.new(2026, 11, 30))
      expect(result.first).to have_attributes(ca_type: :dividend, cash: BigDecimal("0.26"), ex_date: Date.new(2026, 11, 10))

      stub_json(:get, "#{PAPER}/v2/corporate_actions/announcements/ca1", announcement)
      expect(client.corporate_actions.announcement("ca1").id).to eq("ca1")

      stub_json(:get, "#{PAPER}/v2/corporate_actions/announcements", nil,
        query: {"ca_types" => "split", "since" => "2026-10-01", "until" => "2026-11-30"})
      expect(client.corporate_actions.announcements(ca_types: "split", since: "2026-10-01", until: "2026-11-30")).to eq([])
    end
  end
end
