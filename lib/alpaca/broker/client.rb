# frozen_string_literal: true

module Alpaca
  module Broker
    # Broker API client (https://docs.alpaca.markets/us/docs/about-broker-api).
    #
    #   broker = Alpaca::Broker::Client.new(client_id: "...", client_secret: "...")   # sandbox by default
    #   broker = Alpaca::Broker::Client.new(client_id: "...", client_assertion: -> { sign_jwt }, sandbox: false)
    #   broker = Alpaca::Broker::Client.new(key_id: "...", secret_key: "...")         # legacy HTTP Basic keys
    #
    #   account = broker.accounts.create(contact: {...}, identity: {...}, ...)
    #   broker.trading(account.id).orders.create(symbol: "AAPL", qty: 1, side: :buy, type: :market, time_in_force: :day)
    class Client < Alpaca::Client
      LIVE_URL = "https://broker-api.alpaca.markets"
      SANDBOX_URL = "https://broker-api.sandbox.alpaca.markets"
      LIVE_TOKEN_URL = "https://authx.alpaca.markets/v1/oauth2/token"
      SANDBOX_TOKEN_URL = "https://authx.sandbox.alpaca.markets/v1/oauth2/token"

      def initialize(client_id: nil, client_secret: nil, client_assertion: nil, key_id: nil, secret_key: nil,
        sandbox: nil, base_url: nil, token_url: nil, config: Alpaca.configuration, &faraday)
        @sandbox = sandbox.nil? ? config.broker_sandbox : sandbox
        auth = build_auth(client_id, client_secret, client_assertion, key_id, secret_key, token_url, config)
        super(base_url: base_url || (@sandbox ? SANDBOX_URL : LIVE_URL), auth: auth, config: config, &faraday)
      end

      def sandbox? = @sandbox

      # Market Data client authenticated with this Broker client's credentials
      # (data.sandbox.alpaca.markets in sandbox).
      def market_data(feed: nil)
        @market_data ||= MarketData::Client.new(auth: connection.auth, sandbox: sandbox?, feed: feed, config: config)
      end

      # Trading on behalf of one account: orders, positions, watchlists, account,
      # portfolio_history, update_account_configuration, trading_limits.
      def trading(account_id)
        (@account_trading ||= {})[account_id] ||= AccountTrading.new(self, account_id)
      end

      # Crypto wallets, transfers, withdrawals and whitelists for one account.
      def crypto_funding(account_id) = CryptoFunding.new(self, scope: path_for(account_id), api_scope: "/v1")

      # Tokenization requests and issuer callbacks for one account.
      def tokenization(account_id) = Tokenization.new(self, scope: path_for(account_id))

      def accounts = resource(:accounts, Accounts)

      def documents = resource(:documents, Documents)

      def kyc = resource(:kyc, KYC)

      def activities = resource(:activities, Activities)

      def ach_relationships = resource(:ach_relationships, ACHRelationships)

      def recipient_banks = resource(:recipient_banks, RecipientBanks)

      def transfers = resource(:transfers, Transfers)

      def journals = resource(:journals, Journals)

      def instant_funding = resource(:instant_funding, InstantFunding)

      def jit = resource(:jit, JIT)

      def funding_wallets = resource(:funding_wallets, FundingWallets)

      def acats = resource(:acats, ACATS)

      def rebalancing = resource(:rebalancing, Rebalancing)

      def ipos = resource(:ipos, IPOs)

      def fpsl = resource(:fpsl, FPSL)

      def reporting = resource(:reporting, Reporting)

      def oauth = resource(:oauth, OAuth)

      # Server-Sent Event streams (trades, activities, journals, transfers, ...).
      def events = resource(:events, Events)

      def assets = resource(:assets, Assets, scope: "/v1")

      def option_contracts = resource(:option_contracts, Trading::OptionContracts, scope: "/v1")

      def corporate_actions = resource(:corporate_actions, Trading::CorporateActions, scope: "/v1")

      def apr_tiers = reference_data.apr_tiers

      def country_info = reference_data.country_info

      def create_agreement(**) = reference_data.create_agreement(**)

      def logo(symbol, **) = reference_data.logo(symbol, **)

      def clock(market = "NYSE", time: nil) = clocks(markets: [market], time: time).first

      def clocks(markets: nil, time: nil) = calendars.clocks(markets: markets, time: time)

      def calendar(market = "NYSE", **) = calendars.calendar(market, **)

      private

      def resource(name, klass, **)
        return super unless klass == Rebalancing

        @resources ||= {}
        @resources[name] ||= Rebalancing.new(self)
      end

      def reference_data = resource(:reference_data, ReferenceData)

      def calendars = resource(:calendars, Trading::Calendars, scope: "/v2")

      def path_for(account_id) = "/v1/accounts/#{HTTP::Params.segment(account_id)}"

      def build_auth(client_id, client_secret, client_assertion, key_id, secret_key, token_url, config)
        if key_id || secret_key || (config.broker_client_id.nil? && client_id.nil? && config.broker_key_id)
          return HTTP::Auth::Basic.new(key_id || config.broker_key_id, secret_key || config.broker_secret_key)
        end

        HTTP::Auth::ClientCredentials.new(
          client_id: client_id || config.broker_client_id,
          client_secret: client_secret || (client_assertion ? nil : config.broker_client_secret),
          client_assertion: client_assertion,
          token_url: token_url || (@sandbox ? SANDBOX_TOKEN_URL : LIVE_TOKEN_URL)
        )
      end
    end
  end
end
