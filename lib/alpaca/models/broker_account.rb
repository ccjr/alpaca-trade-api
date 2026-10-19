# frozen_string_literal: true

module Alpaca
  class Contact < Model
    attribute :email_address, :string
    attribute :phone_number, :string
    attribute :street_address, [:string]
    attribute :unit, :string
    attribute :city, :string
    attribute :state, :string
    attribute :postal_code, :string
    attribute :country, :string
  end

  class Identity < Model
    attribute :given_name, :string
    attribute :middle_name, :string
    attribute :family_name, :string
    attribute :date_of_birth, :date
    attribute :tax_id, :string
    attribute :tax_id_type, :string
    attribute :country_of_citizenship, :string
    attribute :country_of_birth, :string
    attribute :country_of_tax_residence, :string
    attribute :visa_type, :string
    attribute :visa_expiration_date, :date
    attribute :date_of_departure_from_usa, :date
    attribute :permanent_resident, :boolean
    attribute :funding_source, [:string]
    attribute :marital_status, :symbol
    attribute :number_of_dependents, :integer
    attribute :investment_experience_with_stocks, :symbol
    attribute :investment_experience_with_options, :symbol
    attribute :investment_objective, :symbol
    attribute :investment_time_horizon, :symbol
    attribute :liquidity_needs, :symbol
    attribute :risk_tolerance, :symbol
    %i[annual_income_min annual_income_max liquid_net_worth_min liquid_net_worth_max total_net_worth_min
      total_net_worth_max].each { |name| attribute name, :decimal }
  end

  class Disclosures < Model
    attribute :is_control_person, :boolean
    attribute :is_affiliated_exchange_or_finra, :boolean
    attribute :is_politically_exposed, :boolean
    attribute :immediate_family_exposed, :boolean
    attribute :employment_status, :symbol
    attribute :employment_sector, :symbol
    attribute :employer_name, :string
    attribute :employer_address, :string
    attribute :employment_position, :string
    attribute :context, :raw
  end

  class TrustedContact < Model
    attribute :given_name, :string
    attribute :family_name, :string
    attribute :email_address, :string
    attribute :phone_number, :string
    attribute :street_address, [:string]
    attribute :city, :string
    attribute :state, :string
    attribute :postal_code, :string
    attribute :country, :string
  end

  class Agreement < Model
    attribute :agreement, :symbol
    attribute :signed_at, :time
    attribute :ip_address, :string
    attribute :revision, :string
    attribute :account_id, :string
    attribute :party_id, :string
    attribute :signer_party_id, :string
  end

  # Broker customer account (/v1/accounts). Trading balances for the same
  # account come from broker.trading(id).account (an Alpaca::Account).
  class BrokerAccount < Model
    attribute :id, :string
    attribute :account_number, :string
    attribute :account_name, :string
    attribute :account_type, :symbol
    attribute :account_sub_type, :symbol
    attribute :custodial_account_type, :string
    attribute :status, :symbol
    attribute :crypto_status, :symbol
    attribute :currency, :string
    attribute :last_equity, :decimal
    attribute :created_at, :time
    attribute :enabled_assets, [:string]
    attribute :allow_instant_ach, :boolean
    attribute :instant_ach_blocked, :boolean
    attribute :primary_account_holder_id, :string
    attribute :investment_objective, :symbol
    attribute :investment_time_horizon, :symbol
    attribute :liquidity_needs, :symbol
    attribute :risk_tolerance, :symbol
    attribute :contact, Contact
    attribute :identity, Identity
    attribute :disclosures, Disclosures
    attribute :trusted_contact, TrustedContact
    attribute :agreements, [Agreement]
    attribute :trading_configurations, AccountConfigurations
    attribute :documents, :raw
    attribute :beneficiaries, :raw
    attribute :kyc_results, :raw
    attribute :cash_interest, :raw
    attribute :fpsl, :raw
    attribute :minor_identity, :raw
  end

  class AccountDocument < Model
    attribute :id, :string
    attribute :name, :string
    attribute :type, :symbol
    attribute :sub_type, :string
    attribute :date, :date
  end

  # Customer Identification Program results (identity, document, watchlist and KYC checks).
  class CIPInfo < Model
    attribute :id, :string
    attribute :account_id, :string
    attribute :provider_name, [:string]
    attribute :created_at, :time
    attribute :updated_at, :time
    attribute :kyc, :raw
    attribute :document, :raw
    attribute :photo, :raw
    attribute :identity, :raw
    attribute :watchlist, :raw
  end

  class OptionsApproval < Model
    attribute :id, :string
    attribute :account_id, :string
    attribute :requested_level, :integer
    attribute :approved_level, :integer
    attribute :status, :symbol
    attribute :requester, :symbol
    attribute :created_at, :time
    attribute :updated_at, :time
  end

  class AssetEntryRequirements < Model
    attribute :symbol, :string
    attribute :regt_long, :decimal
    attribute :regt_short, :decimal
  end

  class CountryInfo < Model
    attribute :full_name, :string
    attribute :securities_risk_rating, :symbol
    attribute :crypto_risk_rating, :symbol
    attribute :crypto_supported_states, [:string]
  end

  class IRAExcessContribution < Model
    attribute :account_id, :string
    attribute :tax_year, :integer
    attribute :total_contribution_amount, :decimal
  end

  class OAuthClient < Model
    attribute :client_id, :string
    attribute :name, :string
    attribute :description, :string
    attribute :url, :string
    attribute :terms_of_use, :string
    attribute :privacy_policy, :string
    attribute :status, :symbol
    attribute :redirect_uri, [:string]
    attribute :live_trading_approved, :boolean
  end

  class OAuthAuthorization < Model
    attribute :code, :string
    attribute :client_id, :string
    attribute :redirect_uri, :string
    attribute :scope, :string
  end

  class OAuthToken < Model
    attribute :access_token, :string
    attribute :token_type, :string
    attribute :scope, :string
  end
end
