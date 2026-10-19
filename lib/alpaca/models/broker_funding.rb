# frozen_string_literal: true

module Alpaca
  class ACHRelationship < Model
    attribute :id, :string
    attribute :account_id, :string
    attribute :account_owner_name, :string
    attribute :bank_account_type, :symbol
    attribute :bank_account_number, :string
    attribute :bank_routing_number, :string
    attribute :nickname, :string
    attribute :status, :symbol
    attribute :created_at, :time
    attribute :updated_at, :time
  end

  # Wire recipient bank (/recipient_banks).
  class Bank < Model
    attribute :id, :string
    attribute :account_id, :string
    attribute :name, :string
    attribute :status, :symbol
    attribute :bank_code, :string
    attribute :bank_code_type, :symbol
    attribute :account_number, :string
    attribute :street_address, :string
    attribute :city, :string
    attribute :state_province, :string
    attribute :postal_code, :string
    attribute :country, :string
    attribute :extra_fields, :raw
    attribute :created_at, :time
    attribute :updated_at, :time
  end

  class Transfer < Model
    attribute :id, :string
    attribute :account_id, :string
    attribute :relationship_id, :string
    attribute :bank_id, :string
    attribute :type, :symbol
    attribute :direction, :symbol
    attribute :status, :symbol
    attribute :reason, :string
    attribute :amount, :decimal
    attribute :requested_amount, :decimal
    attribute :instant_amount, :decimal
    attribute :fee, :decimal
    attribute :fee_payment_method, :string
    attribute :additional_information, :string
    attribute :ira, :raw
    attribute :hold_until, :time
    attribute :expires_at, :time
    attribute :created_at, :time
    attribute :updated_at, :time
  end

  # JNLC (cash) or JNLS (securities) journal between two accounts.
  class Journal < Model
    attribute :id, :string
    attribute :entry_type, :symbol
    attribute :from_account, :string
    attribute :to_account, :string
    attribute :status, :symbol
    attribute :symbol, :string
    attribute :qty, :decimal
    attribute :price, :decimal
    attribute :net_amount, :decimal
    attribute :currency, :string
    attribute :description, :string
    attribute :settle_date, :date
    attribute :system_date, :date
    attribute :created_at, :time
    attribute :transmitter_name, :string
    attribute :transmitter_account_number, :string
    attribute :transmitter_address, :string
    attribute :transmitter_financial_institution, :string
    attribute :transmitter_timestamp, :time
    attribute :transmitter_info, :raw
    # Batch journal responses only.
    attribute :error_message, :string
  end

  class InstantFunding < Model
    attribute :id, :string
    attribute :account_no, :string
    attribute :source_account_no, :string
    attribute :status, :symbol
    attribute :amount, :decimal
    attribute :remaining_payable, :decimal
    attribute :total_interest, :decimal
    attribute :system_date, :date
    attribute :deadline, :date
    attribute :created_at, :time
    attribute :fees, :raw
    attribute :interests, :raw
  end

  class FundingLimit < Model
    attribute :account_no, :string
    attribute :amount_limit, :decimal
    attribute :amount_available, :decimal
    attribute :amount_in_use, :decimal
  end

  class InstantFundingReport < Model
    attribute :account_no, :string
    attribute :system_date, :date
    attribute :deadline, :date
    attribute :total_amount_owed, :decimal
    attribute :total_interest_penalty, :decimal
    attribute :instant_funding_transfers, [InstantFunding]
  end

  # Instant-funding or JIT settlement.
  class Settlement < Model
    attribute :id, :string
    attribute :status, :symbol
    attribute :asset_class, :symbol
    attribute :currency, :string
    attribute :source_account_number, :string
    attribute :total_amount, :decimal
    attribute :interest_amount, :decimal
    attribute :additional_info, :string
    attribute :reason, :string
    attribute :created_at, :time
    attribute :updated_at, :time
    attribute :completed_at, :time
  end

  class JITLedger < Model
    attribute :id, :string
    attribute :ledger_name, :string
    attribute :ledger_no, :string
    attribute :status, :string
    attribute :created_at, :time
    # Present on /balances.
    attribute :starting_balance, :decimal
    attribute :ending_balance, :decimal
    attribute :activity_amount, :decimal
    attribute :transactions, :raw
  end

  class DailyTradingLimit < Model
    attribute :correspondent, :string
    attribute :daily_net_limit, :decimal
    attribute :in_use_limit, :decimal
    attribute :cash_held, :decimal
    attribute :executed_buys, :decimal
    attribute :executed_sells, :decimal
    attribute :open_buys, :decimal
    attribute :open_sells, :decimal
  end

  # Global funding wallet (multi-currency deposits/withdrawals, v1beta).
  class FundingWallet < Model
    attribute :account_id, :string
    attribute :status, :symbol
    attribute :created_at, :time
  end

  class FundingWalletRecipientBank < Model
    attribute :id, :string
    attribute :account_number, :string
    attribute :iban, :string
    attribute :bic_swift, :string
    attribute :routing_code, :string
    attribute :routing_code_type, :string
    attribute :currency, :string
    attribute :payment_types, [:string]
    attribute :first_name, :string
    attribute :last_name, :string
    attribute :company_name, :string
    attribute :street_address, :string
    attribute :city, :string
    attribute :state_or_province, :string
    attribute :postal_code, :string
    attribute :country, :string
    attribute :created_at, :time
    attribute :updated_at, :time
  end

  class FundingWalletTransfer < Model
    attribute :id, :string
    attribute :account_id, :string
    attribute :direction, :symbol
    attribute :status, :symbol
    attribute :payment_type, :symbol
    attribute :original_amount, :decimal
    attribute :original_currency, :string
    attribute :requested_amount, :decimal
    attribute :total_amount, :decimal
    attribute :fees, :raw
    attribute :usd, :raw
    attribute :created_at, :time
    attribute :updated_at, :time
  end

  class DemoFundingTransfer < Model
    attribute :amount, :decimal
    attribute :currency, :string
    attribute :receiver_account_number, :string
    attribute :receiver_routing_code, :string
  end

  class AcatsTransfer < Model
    attribute :acats_id, :string
    attribute :account_id, :string
    attribute :account_name, :string
    attribute :account_number, :string
    attribute :account_type, :symbol
    attribute :contra_account_number, :string
    attribute :contra_broker_name, :string
    attribute :contra_broker_number, :string
    attribute :contra_broker_type, :symbol
    attribute :direction, :symbol
    attribute :transfer_type, :symbol
    attribute :transfer_identifier, :string
    attribute :original_transfer_identifier, :string
    attribute :total_transfer_value, :decimal
    attribute :ip_address, :string
    attribute :status, :raw
    attribute :rejection_details, :raw
    attribute :settlement_date, :time
    attribute :created_at, :time

    def id = acats_id
  end

  class AcatsAsset < Model
    attribute :symbol, :string
    attribute :cusip, :string
    attribute :isin, :string
    attribute :asset_class, :symbol
    attribute :asset_description, :string
    attribute :position, :symbol
    attribute :status, :symbol
    attribute :qty, :decimal
    attribute :amount, :decimal
    attribute :currency_code, :string
    attribute :rejection_message, :string
  end

  class AcatsContraBroker < Model
    attribute :name, :string
    attribute :number, :string
    attribute :type, :symbol
  end
end
