# frozen_string_literal: true

module Alpaca
  module Trade
    module Api
      class Bar
        attr_reader :time, :open, :high, :low, :close, :volume

        def initialize(json)
          @time = Time.at(json['t'])
          @open = BigDecimal(json['o'], 2)
          @high = BigDecimal(json['h'], 2)
          @low = BigDecimal(json['l'], 2)
          @close = BigDecimal(json['c'], 2)
          @volume = json['v']
        end
      end
    end
  end
end
