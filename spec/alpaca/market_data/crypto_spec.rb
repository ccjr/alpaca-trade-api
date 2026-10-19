# frozen_string_literal: true

RSpec.describe Alpaca::MarketData::Crypto do
  let(:client) { Alpaca::MarketData::Client.new(key_id: "KEY", secret_key: "SECRET", feed: :sip) }
  let(:crypto) { client.crypto }

  it "returns bars with fractional volume and no stock feed" do
    stub_json(:get, "#{DATA}/v1beta3/crypto/us/bars", openapi_example(:market_data, "/v1beta3/crypto/{loc}/bars").merge("next_page_token" => nil),
      query: {"symbols" => "BTC/USD", "timeframe" => "1Min"})
    bar = crypto.bars("BTC/USD", timeframe: "1Min").first
    expect(bar).to be_a(Alpaca::MarketData::CryptoBar)
    expect(bar).to have_attributes(symbol: "BTC/USD", close: BigDecimal(29_003), volume: BigDecimal("0.01"), trade_count: 4)
  end

  it "accepts another location" do
    stub_json(:get, "#{DATA}/v1beta3/crypto/eu-1/trades",
      openapi_example(:market_data, "/v1beta3/crypto/{loc}/trades").merge("next_page_token" => nil),
      query: {"symbols" => "BTC/USD,ETH/USD"})
    trades = crypto.trades(%w[BTC/USD ETH/USD], loc: "eu-1").to_h
    expect(trades["ETH/USD"].map(&:size)).to eq([BigDecimal("0.06"), BigDecimal("0.136")])
    expect(trades["BTC/USD"].first).to have_attributes(taker_side: :S, id: 31_455_289, price: BigDecimal(29_791))
  end

  it "returns quotes" do
    stub_json(:get, "#{DATA}/v1beta3/crypto/us/quotes",
      openapi_example(:market_data, "/v1beta3/crypto/{loc}/quotes").merge("next_page_token" => nil),
      query: {"symbols" => "BTC/USD,ETH/USD", "sort" => "desc"})
    quote = crypto.quotes(%w[BTC/USD ETH/USD], sort: :desc).first
    expect(quote).to have_attributes(bid_size: BigDecimal("0.3544"), ask_size: BigDecimal("3.252"), ask_price: BigDecimal(29_059))
  end

  it "returns latest values keyed by symbol, or one value for a String" do
    stub_json(:get, "#{DATA}/v1beta3/crypto/us/latest/bars", openapi_example(:market_data, "/v1beta3/crypto/{loc}/latest/bars"),
      query: {"symbols" => "BTC/USD"})
    expect(crypto.latest_bars("BTC/USD").vwap).to eq(BigDecimal(29_001))

    stub_json(:get, "#{DATA}/v1beta3/crypto/us/latest/trades", openapi_example(:market_data, "/v1beta3/crypto/{loc}/latest/trades"),
      query: {"symbols" => "BTC/USD,ETH/USD"})
    expect(crypto.latest_trades(%w[BTC/USD ETH/USD]).transform_values(&:price))
      .to eq("BTC/USD" => BigDecimal(29_791), "ETH/USD" => BigDecimal("2027.6"))

    stub_json(:get, "#{DATA}/v1beta3/crypto/us/latest/quotes", openapi_example(:market_data, "/v1beta3/crypto/{loc}/latest/quotes"),
      query: {"symbols" => "ETH/USD"})
    expect(crypto.latest_quotes("ETH/USD").bid_size).to eq(BigDecimal("4.76"))
  end

  it "returns order books" do
    stub_json(:get, "#{DATA}/v1beta3/crypto/us/latest/orderbooks",
      openapi_example(:market_data, "/v1beta3/crypto/{loc}/latest/orderbooks"), query: {"symbols" => "BTC/USD"})
    book = crypto.latest_orderbooks(%w[BTC/USD])["BTC/USD"]
    expect(book).to be_a(Alpaca::MarketData::Orderbook)
    expect(book.bids.first).to have_attributes(price: BigDecimal(20_846), size: BigDecimal("0.1902"))
    expect(book.asks.map(&:price)).to eq([BigDecimal(20_902), BigDecimal(21_444)])
    expect(book.timestamp.year).to eq(2022)
  end

  it "returns snapshots" do
    stub_json(:get, "#{DATA}/v1beta3/crypto/us/snapshots", openapi_example(:market_data, "/v1beta3/crypto/{loc}/snapshots"),
      query: {"symbols" => "BTC/USD"})
    snapshot = crypto.snapshots("BTC/USD")
    expect(snapshot).to be_a(Alpaca::MarketData::CryptoSnapshot)
    expect(snapshot.daily_bar.volume).to eq(BigDecimal("67.3518"))
    expect(snapshot.latest_trade).to have_attributes(taker_side: :B, size: BigDecimal("0.0543"))
    expect(snapshot.latest_quote.bid_size).to eq(BigDecimal("0.395"))

    stub_json(:get, "#{DATA}/v1beta3/crypto/us/snapshots", {"snapshots" => {}}, query: {"symbols" => "DOGE/USD"})
    expect(crypto.snapshots("DOGE/USD")).to be_nil

    stub_json(:get, "#{DATA}/v1beta3/crypto/us/snapshots", nil, query: {"symbols" => "DOGE/USD"})
    expect(crypto.snapshots(%w[DOGE/USD])).to eq({})
  end
end
