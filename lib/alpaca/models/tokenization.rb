# frozen_string_literal: true

module Alpaca
  # Instant Tokenization Network mint/redeem request.
  class TokenizationRequest < Model
    attribute :tokenization_request_id, :string
    attribute :client_request_id, :string
    attribute :issuer_request_id, :string
    attribute :client_account_id, :string
    attribute :type, :symbol
    attribute :status, :symbol
    attribute :issuer, :string
    attribute :network, :string
    attribute :underlying_symbol, :string
    attribute :token_symbol, :string
    attribute :qty, :decimal
    attribute :fees, :decimal
    attribute :wallet_address, :string
    attribute :tx_hash, :string
    attribute :created_at, :time
    attribute :updated_at, :time

    def id = tokenization_request_id
  end
end
