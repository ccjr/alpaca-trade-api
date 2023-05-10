# frozen_string_literal: true
module Alpaca
  module Market
    class StockClient < Client
      # https://alpaca.markets/docs/api-references/market-data-api/stock-pricing-data/historical/#auctions
      def auctions
      end

      # https://alpaca.markets/docs/api-references/market-data-api/stock-pricing-data/historical/#bars
      def bars(symbol, timeframe, data_start: nil, data_end: nil, limit: 100, page_token: nil, adjustment: nil, asof: nil, feed: nil, currency: nil)
        params = {
          asof: asof,
          adjustment: adjustment,
          currency: currency,
          end: data_end,
          feed: feed,
          limit: limit,
          page_token: page_token,
          start: data_start,
          timeframe: timeframe,
        }
        response = get_request(HOST, "/v2/stocks/#{symbol}/bars", params.compact)
        json = JSON.parse(response.body)

        {
          bars: json['bars'].map { |item| Alpaca::Market::Stock::Bar.new(item) },
          symbol: json['symbol'],
          next_page_token: json['next_page_token']
        }.compact
      end

      # https://alpaca.markets/docs/api-references/market-data-api/stock-pricing-data/historical/#latest-bar
      def latest_bar(symbol, feed: nil, currency: nil)
        params = {
          currency: currency,
          feed: feed,
        }

        response = get_request(HOST, "/v2/stocks/#{symbol}/bars/latest", params.compact)
        json = JSON.parse(response.body)

        {
          bar: Alpaca::Market::Stock::Bar.new(json['bar']),
          symbol: json['symbol'],
        }
      end

      # https://alpaca.markets/docs/api-references/market-data-api/stock-pricing-data/historical/#latest-multi-bars
      def latest_multi_bars
      end

      # https://alpaca.markets/docs/api-references/market-data-api/stock-pricing-data/historical/#latest-multi-quotes
      def latest_multi_quotes
      end

      # https://alpaca.markets/docs/api-references/market-data-api/stock-pricing-data/historical/#latest-multi-trades
      def latest_multi_trades
      end

      # https://alpaca.markets/docs/api-references/market-data-api/stock-pricing-data/historical/#latest-quote
      def latest_quote
      end

      # https://alpaca.markets/docs/api-references/market-data-api/stock-pricing-data/historical/#latest-trade
      def latest_trade
      end

      # https://alpaca.markets/docs/api-references/market-data-api/stock-pricing-data/historical/#multi-auctions
      def multi_auctions
      end

      # https://alpaca.markets/docs/api-references/market-data-api/stock-pricing-data/historical/#multi-bars
      def multi_bars
      end

      # https://alpaca.markets/docs/api-references/market-data-api/stock-pricing-data/historical/#multi-quotes
      def multi_quotes
      end

      # https://alpaca.markets/docs/api-references/market-data-api/stock-pricing-data/historical/#multi-snapshots
      def multi_snapshots
      end

      # https://alpaca.markets/docs/api-references/market-data-api/stock-pricing-data/historical/#multi-trades
      def multi_trades
      end

      # https://alpaca.markets/docs/api-references/market-data-api/stock-pricing-data/historical/#quotes
      def quotes
      end

      # https://alpaca.markets/docs/api-references/market-data-api/stock-pricing-data/historical/#snapshot
      def snapshot
      end

      # https://alpaca.markets/docs/api-references/market-data-api/stock-pricing-data/historical/#trades
      def trades(symbol, data_start: nil, data_end: nil, limit: 100, page_token: nil, adjustment: nil, asof: nil, feed: nil, currency: nil)
        params = {
          asof: asof,
          adjustment: adjustment,
          currency: currency,
          end: data_end,
          feed: feed,
          limit: limit,
          page_token: page_token,
          start: data_start,
        }
        response = get_request(HOST, "/v2/stocks/#{symbol}/trades", params.compact)
        json = JSON.parse(response.body)

        {
          trades: json['trades'].map { |item| Alpaca::Market::Stock::Trade.new(item) },
          symbol: json['symbol'],
          next_page_token: json['next_page_token']
        }.compact
      end
    end
  end
end
