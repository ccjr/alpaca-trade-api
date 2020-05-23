# frozen_string_literal: true

module Alpaca
  module Trade
    module Api
      class TradeActivity
        ATTRIBUTES = %w(id activity_type transaction_time type price qty side
                        symbol leaves_qty order_id cum_qty)

        attr_reader :id, :activity_type, :transaction_time, :type, :price, :qty,
                    :side, :symbol, :leaves_qty, :order_id, :cum_qty

        def initialize(json)
          @id = json['id']
          @activity_type = json['activity_type']
          @transaction_time = json['transaction_time']
          @type = json['type']
          @price = json['price']
          @qty = json['qty']
          @side = json['side']
          @symbol = json['symbol']
          @leaves_qty = json['leaves_qty']
          @order_id = json['order_id']
          @cum_qty = json['cum_qty']
        end
      end
    end
  end
end
