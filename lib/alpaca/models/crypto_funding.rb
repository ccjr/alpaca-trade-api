# frozen_string_literal: true

module Alpaca
  class CryptoWallet < Model
    attribute :id, :string
    attribute :asset, :string
    attribute :address, :string
    attribute :chain, :string
    attribute :created_at, :time
  end

  class CryptoTransfer < Model
    attribute :id, :string
    attribute :asset, :string
    attribute :chain, :string
    attribute :direction, :symbol
    attribute :status, :symbol
    attribute :amount, :decimal
    attribute :fees, :decimal
    attribute :network_fee, :decimal
    attribute :usd_value, :decimal
    attribute :from_address, :string
    attribute :to_address, :string
    attribute :tx_hash, :string
    attribute :created_at, :time
  end

  class WhitelistedAddress < Model
    attribute :id, :string
    attribute :asset, :string
    attribute :address, :string
    attribute :chain, :string
    attribute :status, :symbol
    attribute :created_at, :time
    attribute :travel_rule_info, :raw
  end

  class CryptoFeeEstimate < Model
    attribute :fee, :decimal
    attribute :network_fee, :decimal
  end

  # Virtual Asset Service Provider (travel-rule beneficiary exchange).
  class VASP < Model
    attribute :id, :string
    attribute :did, :string
    attribute :name, :string
    attribute :website, :string
    attribute :country, :string
  end

  class VASPSearchResult < Model
    attribute :vasps, [VASP]
    attribute :page, :integer
    attribute :pages, :integer
    attribute :total, :integer
  end
end
