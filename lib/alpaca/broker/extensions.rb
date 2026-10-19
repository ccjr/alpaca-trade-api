# frozen_string_literal: true

module Alpaca
  module Broker
    # Trading API assets plus Broker-only fixed income and entry requirements.
    class Assets < Trading::Assets
      # Regulation T requirements per symbol.
      operation broker: "get-asset-entry-requirements"
      def entry_requirements(symbols)
        http_get("/v1/assets/entry-requirements", query: {symbols: Array(symbols)}, model: AssetEntryRequirements) || []
      end

      # Filters: bond_status, isins, cusips, tickers.
      operation broker: "UsCorporates"
      def us_corporates(**params)
        data = http_get("/v1/assets/fixed_income/us_corporates", query: params)
        Bond.build(data && data["us_corporates"]) || []
      end

      # Filters: subtype (:bill, :note, :bond, :strips, :tips, :floating), bond_status, cusips, isins.
      operation broker: "UsTreasuries"
      def us_treasuries(**params)
        data = http_get("/v1/assets/fixed_income/us_treasuries", query: params)
        Bond.build(data && data["us_treasuries"]) || []
      end
    end

    # Crypto funding for one account; adds withdrawals to the Trading API resource.
    class CryptoFunding < Trading::CryptoFunding
      operation broker: "createCryptoTransferForAccount"
      def withdraw(amount:, address:, asset:, **params)
        http_post(scoped("wallets/transfers"), body: {amount: amount, address: address, asset: asset, **params},
          model: CryptoTransfer)
      end
    end

    # Tokenization for one account; adds the issuer-side callbacks.
    class Tokenization < Trading::Tokenization
      operation broker: "getTokenizationRequestByIssuerRequestIDBroker"
      def find_by_issuer_request_id(issuer_request_id)
        http_get("#{scope}/tokenization/requests:by_issuer_request_id",
          query: {issuer_request_id: issuer_request_id}, model: TokenizationRequest)
      end

      # Issuer confirms a mint: tokenization_request_id:, tx_hash:, wallet_address:, ...
      operation broker: "postTokenizationCallbackMint"
      def confirm_mint(tokenization_request_id:, tx_hash:, **params)
        body = {tokenization_request_id: tokenization_request_id, tx_hash: tx_hash, **params}
        http_post(scoped("tokenization/callback/mint"), body: body, model: TokenizationRequest)
      end

      # Issuer reports a redemption: issuer_request_id:, underlying_symbol:, token_symbol:, qty:,
      # network:, wallet_address:, tx_hash:
      operation broker: "postTokenizationRedeem"
      def redeem(idempotency_key: nil, **params)
        http_post(scoped("tokenization/callback/redeem"), body: params, idempotency_key: idempotency_key,
          model: TokenizationRequest)
      end
    end

    # Trading on behalf of one customer account. Same resources and models as
    # Alpaca::Trading::Client, rooted at /v1/trading/accounts/{account_id}.
    #
    #   acct = broker.trading(account_id)
    #   acct.orders.create(symbol: "AAPL", qty: 1, side: :buy, type: :market, time_in_force: :day)
    #   acct.positions.list
    class AccountTrading
      include Trading::AccountScope

      attr_reader :account_id, :connection

      def initialize(client, account_id)
        @account_id = account_id
        @connection = client.connection
        @trading_scope = "/v1/trading/accounts/#{HTTP::Params.segment(account_id)}"
        @resources = {}
      end

      # Real-time trading limits (accounts with the feature enabled).
      def trading_limits = account_details.trading_limits

      def inspect = "#<#{self.class.name} #{account_id}>"

      private

      attr_reader :trading_scope

      def resource(name, klass, **) = (@resources[name] ||= klass.new(self, **))
    end
  end
end
