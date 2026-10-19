# frozen_string_literal: true

module Alpaca
  module MarketData
    # Historical market data: a lazy, auto-paginating Collection of records,
    # each tagged with its symbol. `limit` is the page size (it applies across
    # all symbols, so one symbol can span several pages); cap with first(n).
    #
    #   bars = data.stocks.bars(%w[AAPL MSFT], timeframe: "1Day", start: Date.new(2025, 1, 1))
    #   bars.each { |bar| bar.symbol; bar.close }  # streams pages
    #   bars.to_h                                  # => {"AAPL" => [Bar, ...], "MSFT" => [...]}
    class Series < Collection
      # Fetches every page and groups the records by symbol. With a block,
      # behaves like Enumerable#to_h.
      def to_h(&block)
        return super if block

        each_with_object({}) { |record, out| (out[record.symbol] ||= []) << record }
      end
    end
  end
end
