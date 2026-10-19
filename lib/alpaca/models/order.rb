# frozen_string_literal: true

module Alpaca
  class Order < Model
    attribute :id, :string
    attribute :client_order_id, :string
    attribute :symbol, :string
    attribute :asset_id, :string
    attribute :asset_class, :symbol
    attribute :side, :symbol
    attribute :type, :symbol
    attribute :order_type, :symbol
    attribute :order_class, :symbol
    attribute :time_in_force, :symbol
    attribute :status, :symbol
    attribute :position_intent, :symbol
    attribute :extended_hours, :boolean
    attribute :qty, :decimal
    attribute :notional, :decimal
    attribute :filled_qty, :decimal
    attribute :filled_avg_price, :decimal
    attribute :limit_price, :decimal
    attribute :stop_price, :decimal
    attribute :trail_price, :decimal
    attribute :trail_percent, :decimal
    attribute :hwm, :decimal
    attribute :ratio_qty, :decimal
    attribute :commission, :decimal
    attribute :created_at, :time
    attribute :updated_at, :time
    attribute :submitted_at, :time
    attribute :filled_at, :time
    attribute :expired_at, :time
    attribute :expires_at, :time
    attribute :canceled_at, :time
    attribute :failed_at, :time
    attribute :replaced_at, :time
    attribute :replaced_by, :string
    attribute :replaces, :string
    attribute :legs, [Order]

    def open? = %i[new partially_filled accepted pending_new accepted_for_bidding held pending_cancel pending_replace].include?(status)

    def filled? = status == :filled
  end

  # One entry of a bulk response (cancel all orders, close all positions).
  # `status` is the per-item HTTP status; `body` the Order when one was produced.
  class BulkResult < Model
    attribute :id, :string
    attribute :symbol, :string
    attribute :status, :integer
    attribute :body, Order

    def success? = status.between?(200, 299)
  end
end
