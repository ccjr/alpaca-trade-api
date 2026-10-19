# frozen_string_literal: true

RSpec.describe Alpaca::Trading::Orders do
  subject(:orders) { trading_client.orders }

  let(:url) { "#{PAPER}/v2/orders" }
  let(:equity_order) { openapi_example(:trading, "/v2/orders", "post", "Equity") }
  let(:mleg_order) { openapi_example(:trading, "/v2/orders", "post", "MultilegOptions") }

  def order(id, submitted_at = "2026-10-19T14:00:00Z")
    equity_order.merge("id" => id, "submitted_at" => submitted_at)
  end

  describe "#create" do
    it "submits an order with a generated client_order_id" do
      allow(SecureRandom).to receive(:uuid).and_return("generated-id")
      stub = stub_json(:post, url, equity_order, request_body: json_body(
        symbol: "AAPL", qty: "1.5", side: "buy", type: "market", time_in_force: "day", client_order_id: "generated-id"
      ))

      result = orders.create(symbol: "AAPL", qty: BigDecimal("1.5"), side: :buy, type: :market, time_in_force: :day)

      expect(stub).to have_been_requested
      expect(result).to be_a(Alpaca::Order)
      expect(result.side).to eq(:buy)
      expect(result.qty).to be_a(BigDecimal) if result.qty
      expect(result.submitted_at).to be_a(Time)
    end

    it "submits bracket and multi-leg orders" do
      stub = stub_json(:post, url, mleg_order, request_body: json_body(
        order_class: "mleg", qty: "1", type: "limit", limit_price: "0.6", time_in_force: "day", client_order_id: "c1",
        legs: [{symbol: "AAPL250117P00200000", ratio_qty: "1", side: "buy", position_intent: "buy_to_open"},
          {symbol: "AAPL250117C00250000", ratio_qty: "1", side: "buy", position_intent: "buy_to_open"}]
      ))

      result = orders.create(
        order_class: :mleg, qty: "1", type: :limit, limit_price: BigDecimal("0.6"), time_in_force: :day,
        client_order_id: "c1",
        legs: [
          {symbol: Alpaca::OptionSymbol.build("AAPL", expiration: Date.new(2025, 1, 17), type: :put, strike: 200),
           ratio_qty: "1", side: :buy, position_intent: :buy_to_open},
          {symbol: "AAPL250117C00250000", ratio_qty: "1", side: :buy, position_intent: :buy_to_open}
        ]
      )

      expect(stub).to have_been_requested
      expect(result.order_class).to eq(:mleg)
      expect(result.legs).to all(be_a(Alpaca::Order))
      expect(result.legs.size).to eq(mleg_order["legs"].size)
    end

    it "raises UnknownOrderStateError when the submission outcome is unknown" do
      stub_request(:post, url).to_raise(Faraday::TimeoutError)
      expect { orders.create(symbol: "AAPL", qty: 1, side: :buy, type: :market, time_in_force: :day, client_order_id: "x1") }
        .to raise_error(Alpaca::UnknownOrderStateError) { |e| expect(e.client_order_id).to eq("x1") }
    end

    it "raises ForbiddenError for insufficient buying power" do
      stub_json(:post, url, {"code" => 40_310_000, "message" => "insufficient buying power"}, status: 403)
      expect { orders.create(symbol: "AAPL", qty: 1, side: :buy, type: :market, time_in_force: :day) }
        .to raise_error(Alpaca::ForbiddenError) { |e| expect(e.code).to eq(40_310_000) }
    end
  end

  describe "#list" do
    it "follows pages with before_order_id" do
      first = stub_json(:get, url, [order("o1"), order("o2")], query: {"limit" => "2", "status" => "all"})
      second = stub_json(:get, url, [order("o3")], query: {"limit" => "2", "status" => "all", "before_order_id" => "o2"})

      result = orders.list(status: :all, limit: 2).to_a

      expect(result.map(&:id)).to eq(%w[o1 o2 o3])
      expect([first, second]).to all(have_been_requested.once)
    end

    it "uses after_order_id when ascending" do
      stub_json(:get, url, [order("o1")], query: {"limit" => "1", "direction" => "asc"})
      stub_json(:get, url, [], query: {"limit" => "1", "direction" => "asc", "after_order_id" => "o1"})
      expect(orders.list(limit: 1, direction: :asc).map(&:id)).to eq(%w[o1])
    end

    it "pages by submission time when a time window is given" do
      stub_json(:get, url, [order("o1", "2026-10-19T14:00:00Z")], query: {"limit" => "1", "after" => "2026-10-01"})
      stub_json(:get, url, [], query: {"limit" => "1", "after" => "2026-10-01", "until" => "2026-10-19T14:00:00Z"})
      expect(orders.list(limit: 1, after: "2026-10-01").map(&:id)).to eq(%w[o1])

      stub_json(:get, url, [order("o2", "2026-10-19T15:00:00Z")], query: {"limit" => "1", "until" => "2026-10-20", "direction" => "asc"})
      stub_json(:get, url, [], query: {"limit" => "1", "until" => "2026-10-20", "direction" => "asc", "after" => "2026-10-19T15:00:00Z"})
      expect(orders.list(limit: 1, until: "2026-10-20", direction: :asc).map(&:id)).to eq(%w[o2])
    end

    it "requests the maximum page size by default and stops early" do
      stub = stub_json(:get, url, [order("o1")], query: {"limit" => "500", "symbols" => "AAPL,MSFT"})
      expect(orders.list(symbols: %w[AAPL MSFT]).first(1).map(&:id)).to eq(%w[o1])
      expect(stub).to have_been_requested.once
    end
  end

  it "finds orders by id and client order id" do
    stub_json(:get, "#{url}/o1", order("o1"), query: {"nested" => "true"})
    expect(orders.find("o1", nested: true).id).to eq("o1")

    stub_json(:get, "#{PAPER}/v2/orders:by_client_order_id", order("o2"), query: {"client_order_id" => "mine"})
    expect(orders.find_by_client_order_id("mine").id).to eq("o2")
  end

  it "replaces an order" do
    stub = stub_json(:patch, "#{url}/o1", order("o1"), request_body: json_body(qty: "2", limit_price: "101.5"))
    expect(orders.replace("o1", qty: BigDecimal(2), limit_price: "101.5").id).to eq("o1")
    expect(stub).to have_been_requested
  end

  it "cancels one order or all of them" do
    stub_request(:delete, "#{url}/o1").to_return(status: 204)
    expect(orders.cancel("o1")).to be(true)

    stub_json(:delete, url, [{"id" => "o1", "status" => 200, "body" => order("o1")}, {"id" => "o2", "status" => 500}], status: 207)
    results = orders.cancel_all
    expect(results.map(&:success?)).to eq([true, false])
    expect(results.first.body).to be_a(Alpaca::Order)

    stub_json(:delete, url, nil, status: 207)
    expect(orders.cancel_all).to eq([])
  end

  it "only estimates orders through the Broker API" do
    expect { orders.estimate(symbol: "BTCUSD") }.to raise_error(Alpaca::Error, /Broker/)
  end

  it "reports order state helpers" do
    expect(Alpaca::Order.new("status" => "partially_filled")).to be_open
    expect(Alpaca::Order.new("status" => "filled")).to be_filled
  end
end
