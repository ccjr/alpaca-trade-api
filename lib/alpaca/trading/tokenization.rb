# frozen_string_literal: true

module Alpaca
  module Trading
    # Instant Tokenization Network. Scope "/v2" (Trading) or "/v1/accounts/{id}" (Broker).
    class Tokenization < Resource
      # Requests minting of a tokenized asset. Pass idempotency_key: to make
      # retries safe (the request is then also retried automatically on 5xx).
      operation trading: "postTokenizationMint", broker: "postTokenizationMintBroker"
      def mint(underlying_symbol:, qty:, issuer:, network:, wallet_address:, idempotency_key: nil)
        body = {underlying_symbol: underlying_symbol, qty: qty, issuer: issuer, network: network,
                wallet_address: wallet_address}
        http_post(scoped("tokenization/mint"), body: body, idempotency_key: idempotency_key, model: TokenizationRequest)
      end

      # Filters: type, status, underlying_symbol, issuer, network, after, before.
      operation trading: "getTokenizationRequests", broker: "getTokenizationRequestsBroker"
      def requests(**params)
        http_get(scoped("tokenization/requests"), query: params, model: TokenizationRequest) || []
      end

      operation trading: "getTokenizationRequest", broker: "getTokenizationRequestByIDBroker"
      def find(tokenization_request_id)
        http_get(scoped("tokenization/requests", tokenization_request_id), model: TokenizationRequest)
      end

      operation trading: "getTokenizationRequestByClientRequestID", broker: "getTokenizationRequestByClientRequestIDBroker"
      def find_by_client_request_id(client_request_id)
        http_get("#{scope}/tokenization/requests:by_client_request_id",
          query: {client_request_id: client_request_id}, model: TokenizationRequest)
      end
    end
  end
end
