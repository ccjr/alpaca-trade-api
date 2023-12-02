# frozen_string_literal: true

# object
# OHLC aggregate of all the trades in a given interval.

# t date-time required Timestamp in RFC-3339 format with nanosecond precision
# o double required Opening price
# h double required High price
# l double required Low price
# c double required Closing price
# v int64 required Bar volume
# n int64 required Trade count in the bar
# vw double required Volume weighted average price
module Alpaca
  module Trade
    module Api
      class Bar
        attr_reader :time, :open, :high, :low, :close, :volume, :trades, :weighted_average_price

        def initialize(json)
          @time = Time.parse(json['t'])
          @open = BigDecimal(json['o'].to_s)
          @high = BigDecimal(json['h'].to_s)
          @low = BigDecimal(json['l'].to_s)
          @close = BigDecimal(json['c'].to_s)
          @weighted_average_price = BigDecimal(json['vw'].to_s)
          @volume = json['v']
          @trades = json['n']
        end
      end
    end
  end
end
