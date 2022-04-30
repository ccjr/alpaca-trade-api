# frozen_string_literal: true

module Alpaca
  module Market
    module Crypto
      class Bar
        attr_reader :time, :exchange_code, :open, :high, :low, :close, :volume, :number_of_trades,
          :volume_weighted_price

        def initialize(json)
          @time = Time.parse(json['t'])
          @exchange_code = json['x'] if json['x']
          @open = BigDecimal(json['o'].to_s)
          @high = BigDecimal(json['h'].to_s)
          @low = BigDecimal(json['l'].to_s)
          @close = BigDecimal(json['c'].to_s)
          @volume = BigDecimal(json['v'].to_s)
          @number_of_trades = json['n'].to_i
          @volume_weighted_price = BigDecimal(json['vw'].to_s) if json['vw']
        end
      end
    end
  end
end