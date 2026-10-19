# frozen_string_literal: true

RSpec.describe Alpaca::MarketData::Options do
  let(:client) { Alpaca::MarketData::Client.new(key_id: "KEY", secret_key: "SECRET", feed: :sip) }
  let(:options) { client.options }
  let(:contract) { "AAPL240426C00162500" }

  it "returns bars and trades" do
    stub_json(:get, "#{DATA}/v1beta1/options/bars", openapi_example(:market_data, "/v1beta1/options/bars").merge("next_page_token" => nil),
      query: {"symbols" => "AAPL240419P00140000", "timeframe" => "1Day"})
    bar = options.bars("AAPL240419P00140000", timeframe: "1Day").first
    expect(bar).to have_attributes(symbol: "AAPL240419P00140000", close: BigDecimal("0.34"), volume: 12)

    stub_json(:get, "#{DATA}/v1beta1/options/trades", openapi_example(:market_data, "/v1beta1/options/trades").merge("next_page_token" => nil),
      query: {"symbols" => "AAPL240112C00182500", "limit" => "10"})
    trades = options.trades(%w[AAPL240112C00182500], limit: 10).to_a
    expect(trades.map(&:condition)).to eq(%w[I g])
    expect(trades.first).to be_a(Alpaca::MarketData::OptionTrade)
    expect(trades.first[:c]).to eq("I")
  end

  it "returns latest trades and quotes" do
    stub_json(:get, "#{DATA}/v1beta1/options/quotes/latest", openapi_example(:market_data, "/v1beta1/options/quotes/latest"),
      query: {"symbols" => "AAPL240419P00140000,AAPL250321C00190000", "feed" => "indicative"})
    quotes = options.latest_quotes(%w[AAPL240419P00140000 AAPL250321C00190000], feed: :indicative)
    expect(quotes["AAPL250321C00190000"]).to have_attributes(ask_price: BigDecimal(17), ask_size: 622, condition: " ")

    stub_json(:get, "#{DATA}/v1beta1/options/trades/latest", openapi_example(:market_data, "/v1beta1/options/trades/latest"),
      query: {"symbols" => "AAPL250321C00190000"})
    expect(options.latest_trades("AAPL250321C00190000").price).to eq(BigDecimal("17.15"))
  end

  it "follows every snapshot page" do
    example = openapi_example(:market_data, "/v1beta1/options/snapshots/{underlying_symbol}")
    second = {"snapshots" => {"AAPL240426P00150000" => {"impliedVolatility" => 0.4}}, "next_page_token" => nil}
    query = {"symbols" => "#{contract},AAPL240426P00150000"}
    stub_json(:get, "#{DATA}/v1beta1/options/snapshots", example, query: query)
    stub_json(:get, "#{DATA}/v1beta1/options/snapshots", second, query: query.merge("page_token" => example["next_page_token"]))

    snapshots = options.snapshots([contract, "AAPL240426P00150000"])
    expect(snapshots.keys).to eq([contract, "AAPL240426P00150000"])
    snapshot = snapshots[contract]
    expect(snapshot).to be_a(Alpaca::MarketData::OptionSnapshot)
    expect(snapshot.implied_volatility).to eq(BigDecimal("0.3372405712050441"))
    expect(snapshot.greeks).to have_attributes(delta: BigDecimal("0.7521304109871954"), theta: BigDecimal("-0.2847623059595503"))
    expect(snapshot.latest_quote).to have_attributes(condition: "A", bid_size: 16)
    expect(snapshot.latest_trade.price).to eq(BigDecimal("4.1"))
  end

  it "returns one snapshot for a String" do
    example = openapi_example(:market_data, "/v1beta1/options/snapshots/{underlying_symbol}").merge("next_page_token" => nil)
    stub_json(:get, "#{DATA}/v1beta1/options/snapshots", example, query: {"symbols" => contract, "feed" => "opra"})
    expect(options.snapshots(contract, feed: :opra).symbol).to eq(contract)
  end

  it "lazily lists an option chain" do
    example = openapi_example(:market_data, "/v1beta1/options/snapshots/{underlying_symbol}")
    query = {"type" => "call", "expiration_date" => "2024-04-26", "strike_price_gte" => "150"}
    stub_json(:get, "#{DATA}/v1beta1/options/snapshots/AAPL", example, query: query)
    stub_json(:get, "#{DATA}/v1beta1/options/snapshots/AAPL", example.merge("next_page_token" => nil),
      query: query.merge("page_token" => example["next_page_token"]))

    chain = options.chain("AAPL", type: :call, expiration_date: Date.new(2024, 4, 26), strike_price_gte: BigDecimal(150))
    expect(chain).not_to be_a(Alpaca::MarketData::Series)
    expect(chain.first.symbol).to eq(contract)
    expect(chain.to_a.size).to eq(2)
  end

  it "returns metadata" do
    stub_json(:get, "#{DATA}/v1beta1/options/meta/exchanges", {"A" => "AMEX"})
    expect(options.exchanges).to eq("A" => "AMEX")

    stub_json(:get, "#{DATA}/v1beta1/options/meta/conditions/quote", {"A" => "Regular"})
    expect(options.conditions(:quote)).to eq("A" => "Regular")
  end
end
