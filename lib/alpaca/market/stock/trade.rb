# frozen_string_literal: true

module Alpaca
  module Market
    module Stock
      class Trade
        attr_reader :time, :exchange_code, :price, :size, :conditions, :trade_id, :tape, :update

        def initialize(json)
          @time = Time.parse(json['t'])
          @exchange_code = json['x'] if json['x']
          @open = BigDecimal(json['p'].to_s)
          @size = json['s'].to_i
          @conditions = json['c']
          @trade_id = json['i']
          @tape = json['z']
          @update = json['u']
        end
      end
    end
  end
end