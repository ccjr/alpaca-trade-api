# frozen_string_literal: true

RSpec.describe "Trading positions and watchlists" do
  let(:client) { trading_client }
  let(:position) do
    {"asset_id" => "a1", "symbol" => "AAPL", "exchange" => "NASDAQ", "asset_class" => "us_equity",
     "avg_entry_price" => "100.0", "qty" => "5", "qty_available" => "5", "side" => "long", "market_value" => "600.0",
     "cost_basis" => "500.0", "unrealized_pl" => "100.0", "unrealized_plpc" => "0.2", "current_price" => "120.0",
     "lastday_price" => "119.0", "change_today" => "0.0084", "asset_marginable" => true}
  end
  let(:order) { openapi_example(:trading, "/v2/orders", "post", "Equity") }

  describe Alpaca::Trading::Positions do
    let(:positions) { client.positions }

    it "lists and finds positions" do
      stub_json(:get, "#{PAPER}/v2/positions", [position])
      expect(positions.list.first).to have_attributes(symbol: "AAPL", qty: BigDecimal(5), side: :long)
      expect(positions.list.first).to be_long
      expect(positions.list.first).not_to be_short

      stub_json(:get, "#{PAPER}/v2/positions/BTC%2FUSD", position.merge("symbol" => "BTC/USD"))
      expect(positions.find("BTC/USD").symbol).to eq("BTC/USD")

      stub_json(:get, "#{PAPER}/v2/positions", nil)
      expect(positions.list).to eq([])
    end

    it "closes positions" do
      stub_json(:delete, "#{PAPER}/v2/positions/AAPL", order, query: {"percentage" => "50"})
      expect(positions.close("AAPL", percentage: 50)).to be_a(Alpaca::Order)

      stub_json(:delete, "#{PAPER}/v2/positions", [{"symbol" => "AAPL", "status" => 200, "body" => order}],
        status: 207, query: {"cancel_orders" => "true"})
      result = positions.close_all(cancel_orders: true).first
      expect(result).to have_attributes(symbol: "AAPL", status: 200)
      expect(result.body).to be_a(Alpaca::Order)

      stub_json(:delete, "#{PAPER}/v2/positions", nil, status: 207)
      expect(positions.close_all).to eq([])
    end

    it "exercises options and submits do-not-exercise instructions" do
      exercise = stub_request(:post, "#{PAPER}/v2/positions/AAPL270115C00190000/exercise").to_return(status: 200)
      dne = stub_request(:post, "#{PAPER}/v2/positions/AAPL270115C00190000/do-not-exercise").to_return(status: 200)
      expect(positions.exercise("AAPL270115C00190000")).to be(true)
      expect(positions.do_not_exercise("AAPL270115C00190000")).to be(true)
      expect([exercise, dne]).to all(have_been_requested)
    end
  end

  describe Alpaca::Trading::Watchlists do
    let(:watchlists) { client.watchlists }
    let(:watchlist) do
      {"id" => "w1", "account_id" => "acc", "name" => "tech", "created_at" => "2026-10-19T14:00:00Z",
       "updated_at" => "2026-10-19T14:00:00Z", "assets" => [{"symbol" => "AAPL", "class" => "us_equity"}]}
    end
    let(:base) { "#{PAPER}/v2/watchlists" }

    it "lists, finds and creates" do
      stub_json(:get, base, [watchlist.except("assets")])
      expect(watchlists.list.first.name).to eq("tech")

      stub_json(:get, "#{base}/w1", watchlist)
      found = watchlists.find("w1")
      expect(found.symbols).to eq(%w[AAPL])
      expect(found.assets.first.asset_class).to eq(:us_equity)

      stub_json(:get, "#{PAPER}/v2/watchlists:by_name", watchlist, query: {"name" => "tech"})
      expect(watchlists.find_by_name("tech").id).to eq("w1")

      stub_json(:post, base, watchlist, request_body: json_body(name: "tech", symbols: %w[AAPL]))
      expect(watchlists.create(name: "tech", symbols: %w[AAPL]).id).to eq("w1")

      stub_json(:get, base, nil)
      expect(watchlists.list).to eq([])
    end

    it "updates and edits symbols" do
      stub_json(:put, "#{base}/w1", watchlist, request_body: json_body(symbols: %w[MSFT]))
      watchlists.update("w1", symbols: %w[MSFT])

      stub_json(:put, "#{PAPER}/v2/watchlists:by_name", watchlist, query: {"name" => "tech"},
        request_body: json_body(name: "tech2"))
      watchlists.update_by_name("tech", new_name: "tech2")

      stub_json(:post, "#{base}/w1", watchlist, request_body: json_body(symbol: "NVDA"))
      watchlists.add("w1", "NVDA")

      stub_json(:post, "#{PAPER}/v2/watchlists:by_name", watchlist, query: {"name" => "tech"},
        request_body: json_body(symbol: "NVDA"))
      watchlists.add_by_name("tech", "NVDA")

      stub_json(:delete, "#{base}/w1/NVDA", watchlist)
      expect(watchlists.remove("w1", "NVDA").id).to eq("w1")
    end

    it "deletes" do
      stub_request(:delete, "#{base}/w1").to_return(status: 204)
      expect(watchlists.delete("w1")).to be(true)

      stub_request(:delete, "#{PAPER}/v2/watchlists:by_name").with(query: {"name" => "tech"}).to_return(status: 204)
      expect(watchlists.delete_by_name("tech")).to be(true)
    end
  end
end
