# frozen_string_literal: true

module Alpaca
  module Trading
    # Account, configuration and portfolio history. Exposed through client
    # methods (client.account, client.portfolio_history, ...).
    class AccountDetails < Resource
      operation trading: "getAccount", broker: "getTradingAccount"
      def get
        http_get(scoped("account"), model: Account)
      end

      operation trading: "getAccountConfig"
      def configuration
        http_get(scoped("account/configurations"), model: AccountConfigurations)
      end

      operation trading: "patchAccountConfig", broker: "patch-PATCH-v1-trading-accounts-account_id-account-configurations"
      def update_configuration(**params)
        http_patch(scoped("account/configurations"), body: params, model: AccountConfigurations)
      end

      # period: "1W", "1M", "1A"...; timeframe: "1Min", "5Min", "15Min", "1H", "1D";
      # also start, end, intraday_reporting, pnl_reset, cashflow_types.
      operation trading: "getAccountPortfolioHistory", broker: "get-v1-trading-accounts-account_id-account-portfolio-history"
      def portfolio_history(**params)
        http_get(scoped("account/portfolio/history"), query: params, model: PortfolioHistory)
      end

      # Broker only: real-time trading limits (accounts with the feature enabled).
      operation broker: "get-v1-account-trading-limits"
      def trading_limits
        require_broker!(:trading_limits)
        http_get(scoped("limits"))
      end
    end
  end
end
