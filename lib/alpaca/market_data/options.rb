# frozen_string_literal: true

module Alpaca
  module MarketData
    # Option market data (/v1beta1/options). Symbols are OCC contract symbols
    # (see Alpaca::OptionSymbol); feed: :opra (default) or :indicative.
    #
    #   options.snapshots(%w[AAPL250117C00190000])  # => {"AAPL250117C00190000" => OptionSnapshot}
    #   options.chain("AAPL", type: :call, expiration_date: Date.new(2025, 1, 17)).each { |snapshot| ... }
    class Options < Base
      operation market_data: "optionBars"
      def bars(symbols, timeframe:, **params)
        series("/v1beta1/options/bars", "bars", Bar, {symbols: Array(symbols), timeframe: timeframe, **params})
      end

      operation market_data: "OptionTrades"
      def trades(symbols, **params)
        series("/v1beta1/options/trades", "trades", OptionTrade, {symbols: Array(symbols), **params})
      end

      operation market_data: "OptionLatestTrades"
      def latest_trades(symbols, **params)
        latest("/v1beta1/options/trades/latest", symbols, "trades", OptionTrade, params)
      end

      operation market_data: "OptionLatestQuotes"
      def latest_quotes(symbols, **params)
        latest("/v1beta1/options/quotes/latest", symbols, "quotes", OptionQuote, params)
      end

      # Latest trade, quote, greeks and implied volatility. Follows every page.
      operation market_data: "OptionSnapshots"
      def snapshots(symbols, **params)
        all = series("/v1beta1/options/snapshots", "snapshots", OptionSnapshot, {symbols: Array(symbols), **params})
          .to_h { |snapshot| [snapshot.symbol, snapshot] }
        multi?(symbols) ? all : all[symbols.to_s]
      end

      # Lazily lists snapshots for every contract of an underlying. Filters: type,
      # strike_price_gte/lte, expiration_date, expiration_date_gte/lte, root_symbol, updated_since.
      operation market_data: "OptionChain"
      def chain(underlying_symbol, **params)
        series(path("/v1beta1/options/snapshots", underlying_symbol), "snapshots", OptionSnapshot, params,
          klass: Collection)
      end

      # Exchange code => name.
      operation market_data: "OptionMetaExchanges"
      def exchanges
        http_get("/v1beta1/options/meta/exchanges") || {}
      end

      # Condition code => description; ticktype: :trade or :quote.
      operation market_data: "OptionMetaConditions"
      def conditions(ticktype)
        http_get(path("/v1beta1/options/meta/conditions", ticktype)) || {}
      end
    end
  end
end
