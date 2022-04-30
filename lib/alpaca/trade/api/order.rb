# frozen_string_literal: true

module Alpaca
  module Trade
    module Api
      class Order
        attr_reader :id, :asset_class, :asset_id, :canceled_at, :client_order_id,
          :created_at, :expired_at, :extended_hours, :failed_at, :filled_at, :filled_avg_price,
          :filled_qty, :legs, :limit_price, :order_class, :qty, :replaced_at, :replaced_by,
          :replaces, :side, :status, :stop_price, :submitted_at, :symbol, :time_in_force,
          :trail_percent, :trail_price, :type, :updated_at

        def initialize(json)
          @id = json['id']

          @asset_class = json['asset_class']
          @asset_id = json['asset_id']
          @canceled_at = json['canceled_at']
          @client_order_id = json['client_order_id']
          @created_at = json['created_at']
          @expired_at = json['expired_at']
          @extended_hours = json['extended_hours']
          @failed_at = json['failed_at']
          @filled_at = json['filled_at']
          @filled_avg_price = json['filled_avg_price']
          @filled_qty = json['filled_qty']
          @legs = (json['legs'] || []).map {|leg| Order.new(leg)}
          @limit_price = json['limit_price']
          @order_class = json['order_class']
          @qty = json['qty']
          @replaced_at = json['replaced_at']
          @replaced_by = json['replaced_by']
          @replaces = json['replaces']
          @side = json['side']
          @status = json['status']
          @stop_price = json['stop_price']
          @submitted_at = json['submitted_at']
          @symbol = json['symbol']
          @time_in_force = json['time_in_force']
          @trail_percent = json['trail_percent']
          @trail_price = json['trail_price']
          @type = json['type']
          @updated_at = json['updated_at']
        end
      end
    end
  end
end
