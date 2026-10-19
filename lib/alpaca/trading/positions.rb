# frozen_string_literal: true

module Alpaca
  module Trading
    class Positions < Resource
      operation trading: "getAllOpenPositions", broker: "getPositionsForAccount"
      def list
        http_get(scoped("positions"), model: Position) || []
      end

      operation trading: "getOpenPosition", broker: "getPositionsForAccountBySymbol"
      def find(symbol_or_asset_id)
        http_get(scoped("positions", symbol_or_asset_id), model: Position)
      end

      # Liquidates a position, fully or partially (qty: or percentage:).
      # Returns the closing Order.
      operation trading: "deleteOpenPosition", broker: "closePositionForAccountBySymbol"
      def close(symbol_or_asset_id, qty: nil, percentage: nil)
        http_delete(scoped("positions", symbol_or_asset_id), query: {qty: qty, percentage: percentage}, model: Order)
      end

      # Liquidates every position; returns one BulkResult per position.
      operation trading: "deleteAllOpenPositions", broker: "closeAllPositionsForAccount"
      def close_all(cancel_orders: nil)
        http_delete(scoped("positions"), query: {cancel_orders: cancel_orders}, model: BulkResult) || []
      end

      # Exercises all held contracts of an option position. Broker accounts may
      # pass qty: and commission:.
      operation trading: "optionExercise", broker: "optionExercise"
      def exercise(symbol_or_contract_id, **params)
        http_post(scoped("positions", symbol_or_contract_id, "exercise"), body: params.empty? ? nil : params)
        true
      end

      # Instructs Alpaca not to auto-exercise an in-the-money contract at expiry.
      operation trading: "optionDoNotExercise", broker: "optionDoNotExercise"
      def do_not_exercise(symbol_or_contract_id, **params)
        http_post(scoped("positions", symbol_or_contract_id, "do-not-exercise"), body: params.empty? ? nil : params)
        true
      end
    end
  end
end
