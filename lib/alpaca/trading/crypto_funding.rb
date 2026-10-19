# frozen_string_literal: true

module Alpaca
  module Trading
    # Crypto wallets, transfers and withdrawal whitelists.
    # scope: "/v2" (Trading) or "/v1/accounts/{id}" (Broker);
    # api_scope: "/v2" (Trading) or "/v1" (Broker) for account-independent calls.
    class CryptoFunding < Resource
      # Wallets for the account. Passing asset: creates the wallet if it doesn't exist.
      operation trading: "listCryptoFundingWallets", broker: "listCryptoFundingWallets"
      def wallets(**params)
        Array(CryptoWallet.build(http_get(scoped("wallets"), query: params)))
      end

      operation trading: "listCryptoFundingTransfers", broker: "listCryptoFundingTransfers"
      def transfers
        Array(CryptoTransfer.build(http_get(scoped("wallets/transfers"))))
      end

      operation trading: "getCryptoFundingTransfer", broker: "getCryptoFundingTransfer"
      def transfer(transfer_id)
        http_get(scoped("wallets/transfers", transfer_id), model: CryptoTransfer)
      end

      operation trading: "listWhitelistedAddress", broker: "listWhitelistedAddress"
      def whitelisted_addresses
        Array(WhitelistedAddress.build(http_get(scoped("wallets/whitelists"))))
      end

      operation trading: "createWhitelistedAddress", broker: "createWhitelistedAddress"
      def create_whitelisted_address(address:, asset:, **params)
        http_post(scoped("wallets/whitelists"), body: {address: address, asset: asset, **params}, model: WhitelistedAddress)
      end

      operation trading: "deleteWhitelistedAddress", broker: "deleteWhitelistedAddress"
      def delete_whitelisted_address(whitelisted_address_id)
        http_delete(scoped("wallets/whitelists", whitelisted_address_id))
        true
      end

      operation trading: "updateWhitelistedAddressTravelRuleInfo", broker: "updateWhitelistedAddressTravelRuleInfo"
      def update_travel_rule_info(whitelisted_address_id, travel_rule_info)
        http_patch(scoped("wallets/whitelists", whitelisted_address_id, "travel-rule-info"),
          body: {travel_rule_info: travel_rule_info})
        true
      end

      # Estimated network fee for a withdrawal: asset, from_address, to_address, amount.
      operation trading: "getCryptoTransferEstimate", broker: "getCryptoTransferEstimate"
      def fee_estimate(**params)
        http_get("#{api_scope}/wallets/fees/estimate", query: params, model: CryptoFeeEstimate)
      end

      # Searches travel-rule VASPs (exchanges): q, emailDomain, page, per_page, ...
      operation trading: "searchVASPs", broker: "searchVASPs"
      def search_vasps(**params)
        http_get("#{api_scope}/wallets/travel-rule/vasps", query: params, model: VASPSearchResult)
      end

      private

      def api_scope = @options.fetch(:api_scope)
    end
  end
end
