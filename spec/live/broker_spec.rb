# frozen_string_literal: true

RSpec.describe "Broker API (sandbox)" do
  before { skip_without_broker_credentials }

  let(:broker) { sandbox_broker }

  it "authenticates and reads reference data" do
    expect(broker).to be_sandbox
    expect(broker.clock.phase).to be_a(Symbol)
    expect(broker.assets.find("AAPL").symbol).to eq("AAPL")
    expect(broker.accounts.list.first(5)).to all(be_a(Alpaca::Model))
  end

  it "reads an active account's trading data" do
    account = broker.accounts.list(status: "ACTIVE").first
    skip "no ACTIVE account in this sandbox" unless account

    acct = broker.trading(account.id)
    expect(acct.account.buying_power).to be_a(BigDecimal)
    expect(acct.positions.list).to be_an(Array)
    expect(acct.orders.list(status: :all).first(3)).to all(be_a(Alpaca::Order))
    expect(broker.transfers.list(account.id).first(3)).to all(be_a(Alpaca::Model))
  end

  it "replays a bounded window of trade events" do
    events = broker.events.trades(since: Time.now - 86_400, until: Time.now).first(5)
    expect(events).to all(be_a(Alpaca::TradeEvent))
  end

  it "shares its credentials with Market Data" do
    expect(broker.market_data.stocks.latest_trades("AAPL").price).to be_a(BigDecimal)
  end
end
