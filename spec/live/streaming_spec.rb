# frozen_string_literal: true

require "alpaca/streaming"

RSpec.describe "WebSocket streaming (live)" do
  before { skip_without_trading_keys }

  it "authenticates and listens to paper trade updates" do
    updates = Alpaca::Streaming::TradeUpdates.new(paper: true)
    connected = false
    updates.on_connect do
      connected = true
      updates.stop
    end

    expect(run_stream(updates, timeout: 20)).to be(true)
    expect(connected).to be(true)
  end

  it "receives trades from the always-on test feed" do
    stream = Alpaca::Streaming::MarketData.test
    trades = []
    stream.on_trade("FAKEPACA") do |trade|
      trades << trade
      stream.stop
    end

    expect(run_stream(stream)).to be(true)
    expect(trades.first).to have_attributes(symbol: "FAKEPACA", price: be_a(BigDecimal))
  end

  it "receives crypto quotes" do
    stream = Alpaca::Streaming::MarketData.crypto
    quotes = []
    stream.on_quote("BTC/USD") do |quote|
      quotes << quote
      stream.stop
    end

    expect(run_stream(stream)).to be(true)
    expect(quotes.first.bid_price).to be_a(BigDecimal)
  end
end
