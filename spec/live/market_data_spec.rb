# frozen_string_literal: true

RSpec.describe "Market Data API (live, read-only)" do
  before { skip_without_trading_keys }

  let(:data) { market_data }

  it "fetches stock bars across pages and symbols" do
    bars = data.stocks.bars(%w[AAPL MSFT], timeframe: "1Hour", start: Date.today - 14, limit: 10)
    grouped = bars.to_h
    expect(grouped.keys).to contain_exactly("AAPL", "MSFT")
    expect(grouped["AAPL"].size).to be > 10 # more than one page
    bar = grouped["AAPL"].first
    expect(bar.close).to be_a(BigDecimal)
    expect(bar.timestamp).to be_a(Time)

    expect(data.stocks.bars("AAPL", timeframe: "1Day", start: Date.today - 30).first(3).size).to eq(3)
  end

  it "fetches latest values and snapshots" do
    expect(data.stocks.latest_trades("AAPL").price).to be_a(BigDecimal)
    expect(data.stocks.latest_quotes(%w[AAPL MSFT]).keys).to contain_exactly("AAPL", "MSFT")
    snapshot = data.stocks.snapshots("AAPL")
    expect(snapshot.symbol).to eq("AAPL")
    expect(snapshot.latest_trade.price).to be_a(BigDecimal)
  end

  it "fetches crypto and options data" do
    expect(data.crypto.latest_quotes("BTC/USD").bid_price).to be_a(BigDecimal)
    expect(data.crypto.bars("BTC/USD", timeframe: "1Min", start: Time.now - 3600).first(5)).not_to be_empty

    snapshot = data.options.chain("AAPL", type: :call).first
    expect(Alpaca::OptionSymbol.parse(snapshot.symbol).root).to eq("AAPL")
  end

  it "fetches news and screeners" do
    expect(data.news(symbols: %w[AAPL]).first(2).size).to eq(2)
    expect(data.screener.most_actives(top: 5).most_actives.size).to eq(5)
  end
end
