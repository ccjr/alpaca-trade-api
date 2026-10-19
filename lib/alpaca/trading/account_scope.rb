# frozen_string_literal: true

module Alpaca
  module Trading
    # Account-level trading resources, shared by Trading::Client ("/v2") and
    # Broker::AccountTrading ("/v1/trading/accounts/{id}"). Includers provide
    # #trading_scope and #resource(name, klass, **options).
    module AccountScope
      def orders = resource(:orders, Orders, scope: trading_scope)

      def positions = resource(:positions, Positions, scope: trading_scope)

      def watchlists = resource(:watchlists, Watchlists, scope: trading_scope)

      def account = account_details.get

      def update_account_configuration(**) = account_details.update_configuration(**)

      def portfolio_history(**) = account_details.portfolio_history(**)

      private

      def account_details = resource(:account_details, AccountDetails, scope: trading_scope)
    end
  end
end
