# frozen_string_literal: true

module Alpaca
  module MarketData
    # Market Data API client (https://docs.alpaca.markets/us/docs/about-market-data-api).
    #
    #   data = Alpaca::MarketData::Client.new                            # env credentials
    #   data = Alpaca::MarketData::Client.new(key_id: "...", secret_key: "...", feed: :sip)
    #   data = Alpaca::MarketData::Client.new(oauth_token: token)        # Alpaca Connect
    #   data = Alpaca::MarketData::Client.new(auth: broker_auth, sandbox: true)
    #
    # `feed` (default: config.data_feed) is sent with stock requests unless a
    # call passes its own `feed:`. Pass a block to customize the Faraday connection.
    class Client < Alpaca::Client
      LIVE_URL = "https://data.alpaca.markets"
      SANDBOX_URL = "https://data.sandbox.alpaca.markets"

      attr_reader :feed

      # auth: any Alpaca::HTTP::Auth strategy (e.g. a Broker client's), used instead of keys/tokens.
      def initialize(key_id: nil, secret_key: nil, oauth_token: nil, auth: nil, sandbox: false, feed: nil,
        base_url: nil, config: Alpaca.configuration, &faraday)
        @sandbox = sandbox
        @feed = feed || config.data_feed
        auth ||= begin
          oauth_token ||= config.oauth_token unless key_id
          if oauth_token
            HTTP::Auth::Bearer.new(oauth_token)
          else
            HTTP::Auth::ApiKey.new(key_id || config.key_id, secret_key || config.secret_key)
          end
        end
        super(base_url: base_url || (sandbox ? SANDBOX_URL : LIVE_URL), auth: auth, config: config, &faraday)
      end

      def sandbox? = @sandbox

      def stocks = resource(:stocks, Stocks)

      def crypto = resource(:crypto, Crypto)

      def options = resource(:options, Options)

      def screener = resource(:screener, Screener)

      def fixed_income = resource(:fixed_income, FixedIncome)

      # Lazy Collection of NewsArticle: news(symbols: %w[AAPL], include_content: true).first(20)
      def news(**) = resource(:news, News).list(**)

      # Lazy Collection of CorporateAction: corporate_actions(symbols: %w[AAPL], types: %w[cash_dividend])
      def corporate_actions(**) = resource(:corporate_actions, CorporateActions).list(**)

      # Live (and replayed) corporate action changes over SSE:
      #   data.corporate_action_events(since: Time.now - 86_400).each { |event| event.action; event.ca }
      def corporate_action_events(**) = resource(:corporate_action_events, CorporateActionEvents).stream(**)

      # Company logo as a binary String (image/png).
      def logo(symbol, **) = resource(:logos, Logos).fetch(symbol, **)
    end
  end
end
