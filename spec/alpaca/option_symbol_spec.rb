# frozen_string_literal: true

RSpec.describe Alpaca::OptionSymbol do
  it "builds OCC symbols" do
    expect(described_class.build("aapl", expiration: Date.new(2027, 1, 15), type: :call, strike: 190))
      .to eq("AAPL270115C00190000")
    expect(described_class.build("SPY", expiration: "2027-01-15", type: "P", strike: "450.5"))
      .to eq("SPY270115P00450500")
  end

  it "parses OCC symbols" do
    parsed = described_class.parse("AAPL270115C00190000")
    expect(parsed).to have_attributes(root: "AAPL", expiration: Date.new(2027, 1, 15), type: :call,
      strike: BigDecimal(190))
    expect(parsed).to be_call
    expect(parsed).not_to be_put
    expect(parsed.to_s).to eq("AAPL270115C00190000")
    expect(described_class.parse("SPY270115P00450500").strike).to eq(BigDecimal("450.5"))
  end

  it "validates" do
    expect(described_class.valid?("AAPL270115C00190000")).to be(true)
    expect(described_class.valid?("AAPL")).to be(false)
    expect { described_class.parse("AAPL") }.to raise_error(ArgumentError, /invalid OCC/)
    expect { described_class.new(root: "A", expiration: Date.today, type: :straddle, strike: 1) }
      .to raise_error(ArgumentError, /call or :put/)
  end
end
