# frozen_string_literal: true

module Alpaca
  module MarketData
    # Crypto market data (/v1beta3/crypto/{loc}). `loc` defaults to "us"
    # (Alpaca US); others: "us-1" (Kraken US), "us-2", "eu-1" (Kraken EU), "bs-1".
    #
    #   crypto.bars("BTC/USD", timeframe: "1Min").first(60)
    #   crypto.latest_orderbooks(%w[BTC/USD ETH/USD])  # => {"BTC/USD" => Orderbook, ...}
    class Crypto < Base
      DEFAULT_LOC = "us"

      operation market_data: "CryptoBars"
      def bars(symbols, timeframe:, loc: DEFAULT_LOC, **params)
        historical(loc, "bars", symbols, CryptoBar, {timeframe: timeframe, **params})
      end

      operation market_data: "CryptoTrades"
      def trades(symbols, loc: DEFAULT_LOC, **params)
        historical(loc, "trades", symbols, CryptoTrade, params)
      end

      operation market_data: "CryptoQuotes"
      def quotes(symbols, loc: DEFAULT_LOC, **params)
        historical(loc, "quotes", symbols, CryptoQuote, params)
      end

      operation market_data: "CryptoLatestBars"
      def latest_bars(symbols, loc: DEFAULT_LOC)
        latest(path("/v1beta3/crypto", loc, "latest", "bars"), symbols, "bars", CryptoBar)
      end

      operation market_data: "CryptoLatestTrades"
      def latest_trades(symbols, loc: DEFAULT_LOC)
        latest(path("/v1beta3/crypto", loc, "latest", "trades"), symbols, "trades", CryptoTrade)
      end

      operation market_data: "CryptoLatestQuotes"
      def latest_quotes(symbols, loc: DEFAULT_LOC)
        latest(path("/v1beta3/crypto", loc, "latest", "quotes"), symbols, "quotes", CryptoQuote)
      end

      operation market_data: "CryptoLatestOrderbooks"
      def latest_orderbooks(symbols, loc: DEFAULT_LOC)
        latest(path("/v1beta3/crypto", loc, "latest", "orderbooks"), symbols, "orderbooks", Orderbook)
      end

      operation market_data: "CryptoSnapshots"
      def snapshots(symbols, loc: DEFAULT_LOC)
        latest(path("/v1beta3/crypto", loc, "snapshots"), symbols, "snapshots", CryptoSnapshot)
      end

      private

      def historical(loc, kind, symbols, model, params)
        series(path("/v1beta3/crypto", loc, kind), kind, model, {symbols: Array(symbols), **params})
      end
    end
  end
end
