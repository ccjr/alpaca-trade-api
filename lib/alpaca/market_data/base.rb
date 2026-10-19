# frozen_string_literal: true

module Alpaca
  module MarketData
    # Response shapes shared by the market data resources.
    class Base < Resource
      private

      def multi?(symbols) = symbols.is_a?(Array)

      def stock_feed(params) = {feed: client.feed}.merge(params)

      # Historical data: {key => {"AAPL" => [...]}} from multi-symbol paths,
      # {key => [...], "symbol" => "AAPL"} from single-symbol ones.
      def series(path, key, model, query, symbol: nil, klass: Series)
        klass.new do |cursor|
          response = connection.request(:get, path, query: cursor ? query.merge(page_token: cursor) : query)
          data = response.data || {}
          token = data["next_page_token"]
          items = records(data[key], model, response, data["symbol"] || symbol)
          Collection::Page.new(items: items, next_cursor: (token.nil? || token == "") ? nil : token, response: response)
        end
      end

      def records(items, model, response, symbol)
        case items
        when Array then items.map { |item| model.new(item, response: response, symbol: symbol) }
        # Snapshot maps hold one object per symbol, historical maps a list.
        when Hash then items.flat_map { |name, value| records(value.is_a?(Hash) ? [value] : value, model, response, name) }
        else []
        end
      end

      # Latest values and snapshots: one object for a String, a Hash
      # symbol => object for an Array.
      def latest(path, symbols, key, model, query = {}, param: :symbols, id: :symbol)
        response = connection.request(:get, path, query: {param => symbols}.merge(query))
        data = key ? response.data&.dig(key) : response.data
        by_symbol = keyed(data, model, response, id)
        multi?(symbols) ? by_symbol : by_symbol[symbols.to_s]
      end

      # Entries that aren't objects (a top-level "currency") are skipped.
      def keyed(map, model, response, id)
        (map || {}).each_with_object({}) do |(name, item), out|
          out[name] = model.new(item, response: response, **{id => name}) if item.is_a?(Hash)
        end
      end
    end
  end
end
