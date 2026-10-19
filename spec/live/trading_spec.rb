# frozen_string_literal: true

RSpec.describe "Trading API (paper)" do
  before { skip_without_trading_keys }

  let(:trading) { paper_trading }

  it "reads the account, configuration and portfolio history" do
    account = trading.account
    expect(account.status).to eq(:ACTIVE)
    expect(account.buying_power).to be_a(BigDecimal)
    expect(account.response.request_id).not_to be_nil

    expect(trading.account_configuration.to_h).to include(:no_shorting, :fractional_trading)
    history = trading.portfolio_history(period: "1W", timeframe: "1D")
    expect(history.equity).to all(be_a(BigDecimal).or(be_nil))
  end

  it "reads the clock, calendar and assets" do
    clock = trading.clock
    expect(clock.phase).to be_a(Symbol)

    days = trading.calendar("NYSE", start: Date.today, end: Date.today + 14).days
    expect(days).not_to be_empty

    aapl = trading.assets.find("AAPL")
    expect(aapl).to have_attributes(symbol: "AAPL", tradable: true)
    expect(trading.assets.list(status: :active, asset_class: :crypto).first.asset_class).to eq(:crypto)
  end

  it "lists option contracts, positions and activities" do
    contract = trading.option_contracts.list(underlying_symbols: %w[AAPL], limit: 5).first
    expect(Alpaca::OptionSymbol.parse(contract.symbol).root).to eq("AAPL")

    expect(trading.positions.list).to be_an(Array)
    expect(trading.activities.list.first(5)).to all(be_a(Alpaca::Model))
    expect(trading.orders.list(status: :all).first(3)).to all(be_a(Alpaca::Order))
  end

  it "submits, finds, replaces and cancels an order that won't fill" do
    order = trading.orders.create(symbol: "AAPL", qty: 1, side: :buy, type: :limit, limit_price: "1",
      time_in_force: :gtc)
    begin
      expect(order.client_order_id).not_to be_nil
      expect(trading.orders.find(order.id).id).to eq(order.id)
      expect(trading.orders.find_by_client_order_id(order.client_order_id).id).to eq(order.id)

      # Orders queued outside market hours ("accepted") can't be replaced yet.
      if trading.orders.find(order.id).status == :new
        order = trading.orders.replace(order.id, limit_price: "1.01")
        expect(order.limit_price).to eq(BigDecimal("1.01"))
      end
    ensure
      expect(trading.orders.cancel(order.id)).to be(true)
    end
    expect(%i[canceled pending_cancel]).to include(trading.orders.find(order.id).status)
  end

  it "raises structured errors" do
    expect { trading.orders.find(SecureRandom.uuid) }.to raise_error(Alpaca::NotFoundError) { |error|
      expect(error.status).to eq(404)
      expect(error.request_id).not_to be_nil
    }
  end

  it "manages a watchlist" do
    watchlist = trading.watchlists.create(name: live_name("live"), symbols: %w[AAPL])
    begin
      trading.watchlists.add(watchlist.id, "MSFT")
      expect(trading.watchlists.find(watchlist.id).assets.map(&:symbol)).to contain_exactly("AAPL", "MSFT")
      trading.watchlists.remove(watchlist.id, "AAPL")
      expect(trading.watchlists.find_by_name(watchlist.name).assets.map(&:symbol)).to eq(%w[MSFT])
    ensure
      trading.watchlists.delete(watchlist.id)
    end
    expect(trading.watchlists.list.map(&:id)).not_to include(watchlist.id)
  end
end
