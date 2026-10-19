# frozen_string_literal: true

module Alpaca
  module Trading
    # Orders for the Trading API account, or for one Broker account when scoped
    # through Alpaca::Broker::Client#trading(account_id).
    class Orders < Resource
      MAX_PAGE_SIZE = 500

      # Lazily lists orders, following pages. Same filters as the API:
      # status (:open default, :closed, :all), symbols, side, asset_class,
      # after, until, direction, nested. `limit` is the page size.
      #
      #   orders.list(status: :all, symbols: %w[AAPL]).first(20)
      operation trading: "getAllOrders", broker: "getAllOrdersForAccount"
      def list(**params)
        query = {limit: MAX_PAGE_SIZE}.merge(params)
        page_size = query[:limit].to_i
        ascending = query[:direction].to_s == "asc"
        by_time = broker? || query.key?(:after) || query.key?(:until)

        Collection.new do |cursor|
          response = connection.request(:get, scoped("orders"), query: cursor ? query.merge(cursor) : query)
          orders = Order.build(response.data, response: response)
          Collection::Page.new(items: orders, next_cursor: next_cursor(orders, page_size, ascending, by_time),
            response: response)
        end
      end

      operation trading: "getOrderByOrderID", broker: "getOrderForAccount"
      def find(order_id, **params)
        http_get(scoped("orders", order_id), query: params, model: Order)
      end

      operation trading: "getOrderByClientOrderId", broker: "getOrderByClientOrderIdForAccount"
      def find_by_client_order_id(client_order_id)
        http_get("#{scope}/orders:by_client_order_id", query: {client_order_id: client_order_id}, model: Order)
      end

      # Submits an order. A client_order_id is generated when none is given, so
      # an order whose submission times out can still be looked up.
      #
      #   orders.create(symbol: "AAPL", qty: 1, side: :buy, type: :market, time_in_force: :day)
      #   orders.create(order_class: :mleg, qty: 1, type: :limit, limit_price: "0.6", time_in_force: :day,
      #                 legs: [{symbol: "AAPL250117P00200000", ratio_qty: 1, side: :buy, position_intent: :buy_to_open}, ...])
      operation trading: "postOrder", broker: "createOrderForAccount"
      def create(type:, time_in_force:, client_order_id: SecureRandom.uuid, **params)
        body = {type: type, time_in_force: time_in_force, client_order_id: client_order_id, **params}
        http_post(scoped("orders"), body: body, model: Order)
      rescue ConnectionError => e
        raise UnknownOrderStateError.new(e.message, client_order_id: client_order_id)
      end

      # Replaces (PATCH) an open order: qty, time_in_force, limit_price, stop_price, trail, client_order_id.
      operation trading: "patchOrderByOrderId", broker: "replaceOrderForAccount"
      def replace(order_id, **params)
        http_patch(scoped("orders", order_id), body: params, model: Order)
      end

      operation trading: "deleteOrderByOrderID", broker: "deleteOrderForAccount"
      def cancel(order_id)
        http_delete(scoped("orders", order_id))
        true
      end

      # Cancels every open order; returns one BulkResult per order.
      operation trading: "deleteAllOrders", broker: "deleteAllOrdersForAccount"
      def cancel_all
        http_delete(scoped("orders"), model: BulkResult) || []
      end

      # Broker only: estimates an order (e.g. qty for a notional crypto order) without placing it.
      operation broker: "get-v1-trading-accounts-account_id-orders-estimation"
      def estimate(**params)
        require_broker!(:estimate)
        http_post(scoped("orders/estimation"), body: params, model: Order)
      end

      private

      def next_cursor(orders, page_size, ascending, by_time)
        return if orders.size < page_size

        last = orders.last
        if by_time
          ascending ? {after: last.submitted_at} : {until: last.submitted_at}
        else
          ascending ? {after_order_id: last.id} : {before_order_id: last.id}
        end
      end
    end
  end
end
