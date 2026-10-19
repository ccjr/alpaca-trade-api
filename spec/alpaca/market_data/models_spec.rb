# frozen_string_literal: true

RSpec.describe Alpaca::MarketData::Record do
  it "maps wire keys to readable names, also for subclasses" do
    trade = Alpaca::MarketData::CryptoTrade.new({"p" => 1.5, "s" => 2, "tks" => "B", "extra" => 1}, symbol: "BTC/USD")
    expect(trade).to have_attributes(price: BigDecimal("1.5"), size: BigDecimal(2), taker_side: :B, symbol: "BTC/USD")
    expect(trade[:s]).to eq(BigDecimal(2))
    expect(trade[:size]).to eq(BigDecimal(2))
    expect(trade.extra).to eq(1)
    expect(trade.to_h).to eq(price: BigDecimal("1.5"), size: BigDecimal(2), taker_side: :B, extra: 1, symbol: "BTC/USD")
    expect(Alpaca::MarketData::Trade.wire_names).not_to include("tks")
  end

  it "builds without attributes" do
    expect(Alpaca::MarketData::Bar.new(symbol: "AAPL").to_h).to eq(symbol: "AAPL")
  end

  it "supports pattern matching on readable names" do
    case Alpaca::MarketData::Bar.new({"c" => 10, "v" => 5})
    in {close:, volume:}
      expect([close, volume]).to eq([BigDecimal(10), 5])
    end
  end
end
