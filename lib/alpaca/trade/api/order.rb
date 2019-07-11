# frozen_string_literal: true

module Alpaca
  module Trade
    module Api
      class Order
        attr_reader :id, :client_order_id, :created_at, :updated_at, :submitted_at,
          :filled_at, :expired_at, :canceled_at, :failed_at, :asset_id, :symbol,
          :asset_class, :qty, :filled_qty, :type, :side, :time_in_force, :limit_price,
          :stop_price, :filled_avg_price, :status, :extended_hours

        def initialize(json)
          @id = json['id']
          @client_order_id = json['client_order_id']
          @created_at = json['created_at']
          @updated_at = json['updated_at']
          @submitted_at = json['submitted_at']
          @filled_at = json['filled_at']
          @expired_at = json['expired_at']
          @canceled_at = json['canceled_at']
          @failed_at = json['failed_at']
          @asset_id = json['asset_id']
          @symbol = json['symbol']
          @asset_class = json['asset_class']
          @qty = json['qty']
          @filled_qty = json['filled_qty']
          @type = json['type']
          @side = json['side']
          @time_in_force = json['time_in_force']
          @limit_price = json['limit_price']
          @stop_price = json['stop_price']
          @filled_avg_price = json['filled_avg_price']
          @status = json['status']
          @extended_hours = json['extended_hours']
        end
      end
    end
  end
end
