# frozen_string_literal: true

module Alpaca
  module MarketData
    # Stock market data (/v2/stocks). `symbols` is a String for one symbol or an
    # Array for several; the client's default feed is sent unless `feed:` is given.
    #
    #   stocks.bars(%w[AAPL MSFT], timeframe: "1Day", start: Date.new(2025, 1, 1), adjustment: :all).to_h
    #   stocks.trades("AAPL", start: Time.now - 3600).first(100)
    #   stocks.latest_quotes(%w[AAPL MSFT])  # => {"AAPL" => Quote, "MSFT" => Quote}
    #   stocks.snapshots("AAPL")             # => Snapshot
    class Stocks < Base
      # timeframe: "1Min", "15Min", "1Hour", "1Day", "1Week", "1Month" ([1-59]Min, [1-23]Hour, ...).
      operation market_data: %w[StockBars StockBarSingle]
      def bars(symbols, timeframe:, **params)
        historical("bars", symbols, Bar, {timeframe: timeframe, **params})
      end

      operation market_data: %w[StockTrades StockTradeSingle]
      def trades(symbols, **params)
        historical("trades", symbols, Trade, params)
      end

      operation market_data: %w[StockQuotes StockQuoteSingle]
      def quotes(symbols, **params)
        historical("quotes", symbols, Quote, params)
      end

      # Daily opening/closing auctions (DailyAuction records). Only the SIP feed
      # has auctions, so the client's default feed is not applied.
      operation market_data: %w[StockAuctions StockAuctionSingle]
      def auctions(symbols, **params)
        historical("auctions", symbols, DailyAuction, params, feed: false)
      end

      operation market_data: %w[StockLatestBars StockLatestBarSingle]
      def latest_bars(symbols, **params)
        latest_values("bars", "bar", symbols, Bar, params)
      end

      operation market_data: %w[StockLatestTrades StockLatestTradeSingle]
      def latest_trades(symbols, **params)
        latest_values("trades", "trade", symbols, Trade, params)
      end

      operation market_data: %w[StockLatestQuotes StockLatestQuoteSingle]
      def latest_quotes(symbols, **params)
        latest_values("quotes", "quote", symbols, Quote, params)
      end

      # Latest trade, quote, minute bar, daily bar and previous daily bar.
      operation market_data: %w[StockSnapshots StockSnapshotSingle]
      def snapshots(symbols, **params)
        query = stock_feed(params)
        return latest("/v2/stocks/snapshots", symbols, nil, Snapshot, query) if multi?(symbols)

        http_get(path("/v2/stocks", symbols, "snapshot"), query: query, model: Snapshot)
      end

      # Exchange code => name.
      operation market_data: "StockMetaExchanges"
      def exchanges
        http_get("/v2/stocks/meta/exchanges") || {}
      end

      # Condition code => description; ticktype: :trade or :quote, tape: "A", "B" or "C".
      operation market_data: "StockMetaConditions"
      def conditions(ticktype, tape:)
        http_get(path("/v2/stocks/meta/conditions", ticktype), query: {tape: tape}) || {}
      end

      private

      def historical(kind, symbols, model, params, feed: true)
        query = feed ? stock_feed(params) : params
        if multi?(symbols)
          series("/v2/stocks/#{kind}", kind, model, {symbols: symbols, **query})
        else
          series(path("/v2/stocks", symbols, kind), kind, model, query, symbol: symbols.to_s)
        end
      end

      def latest_values(kind, key, symbols, model, params)
        query = stock_feed(params)
        return latest("/v2/stocks/#{kind}/latest", symbols, kind, model, query) if multi?(symbols)

        response = connection.request(:get, path("/v2/stocks", symbols, kind, "latest"), query: query)
        data = response.data || {}
        data[key] && model.new(data[key], response: response, symbol: data["symbol"] || symbols.to_s)
      end
    end
  end
end
