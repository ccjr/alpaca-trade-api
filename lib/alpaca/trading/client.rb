# frozen_string_literal: true

module Alpaca
  module Trading
    # Trading API client (https://docs.alpaca.markets/us/docs/trading-api).
    #
    #   trading = Alpaca::Trading::Client.new                        # env credentials, paper
    #   trading = Alpaca::Trading::Client.new(key_id: "...", secret_key: "...", paper: false)
    #   trading = Alpaca::Trading::Client.new(oauth_token: token)    # Alpaca Connect
    #
    # Pass a block to customize the Faraday connection (middleware, adapter).
    class Client < Alpaca::Client
      include AccountScope

      LIVE_URL = "https://api.alpaca.markets"
      PAPER_URL = "https://paper-api.alpaca.markets"

      def initialize(key_id: nil, secret_key: nil, oauth_token: nil, paper: nil, base_url: nil,
        config: Alpaca.configuration, &faraday)
        @paper = paper.nil? ? config.paper : paper
        oauth_token ||= config.oauth_token unless key_id
        auth = if oauth_token
          HTTP::Auth::Bearer.new(oauth_token)
        else
          HTTP::Auth::ApiKey.new(key_id || config.key_id, secret_key || config.secret_key)
        end
        super(base_url: base_url || (@paper ? PAPER_URL : LIVE_URL), auth: auth, config: config, &faraday)
      end

      def paper? = @paper

      def account_configuration = account_details.configuration

      def activities = resource(:activities, Activities)

      def assets = resource(:assets, Assets, scope: "/v2")

      def option_contracts = resource(:option_contracts, OptionContracts, scope: "/v2")

      def corporate_actions = resource(:corporate_actions, CorporateActions, scope: "/v2")

      def crypto_funding = resource(:crypto_funding, CryptoFunding, scope: "/v2", api_scope: "/v2")

      def locates = resource(:locates, Locates)

      def tokenization = resource(:tokenization, Tokenization, scope: "/v2")

      # Server-Sent Event streams (account activities).
      def events = resource(:events, Events)

      # Clock for one market (default NYSE): phase, is_market_day, next open/close.
      def clock(market = "NYSE", time: nil) = clocks(markets: [market], time: time).first

      def clocks(markets: nil, time: nil) = calendars.clocks(markets: markets, time: time)

      # Trading days for a market: calendar("NYSE", start: Date.today, end: Date.today + 30).days
      def calendar(market = "NYSE", **) = calendars.calendar(market, **)

      private

      def trading_scope = "/v2"

      def calendars = resource(:calendars, Calendars, scope: "/v3")
    end
  end
end
