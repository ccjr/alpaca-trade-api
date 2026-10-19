# frozen_string_literal: true

module Alpaca
  # Process-wide defaults. Every client accepts the same settings as keyword
  # arguments, which take precedence over these values.
  #
  #   Alpaca.configure do |c|
  #     c.logger = Logger.new($stdout)
  #     c.max_retries = 3
  #   end
  class Configuration
    # Trading API / Market Data credentials (APCA_API_KEY_ID, APCA_API_SECRET_KEY).
    attr_accessor :key_id, :secret_key
    # Alpaca Connect OAuth access token, used instead of key_id/secret_key.
    attr_accessor :oauth_token
    # Trading API environment: true for paper-api.alpaca.markets.
    attr_accessor :paper

    # Broker API client-credentials flow (preferred).
    attr_accessor :broker_client_id, :broker_client_secret
    # Broker API legacy key/secret (HTTP Basic).
    attr_accessor :broker_key_id, :broker_secret_key
    # Broker API environment: true for the sandbox hosts.
    attr_accessor :broker_sandbox

    # Default stock data feed (:iex, :sip, :delayed_sip, :boats, :overnight, :otc).
    attr_accessor :data_feed

    # HTTP behaviour.
    attr_accessor :timeout, :open_timeout, :max_retries, :max_retry_interval, :logger, :user_agent, :adapter
    # Seconds without data before an event stream (SSE) is considered dead and
    # reconnected. Alpaca sends heartbeats well within this window.
    attr_accessor :stream_timeout

    def initialize
      @key_id = env("APCA_API_KEY_ID", "ALPACA_API_KEY_ID")
      @secret_key = env("APCA_API_SECRET_KEY", "ALPACA_API_SECRET_KEY")
      @oauth_token = env("APCA_API_OAUTH_TOKEN")
      @paper = !env("APCA_API_BASE_URL").to_s.start_with?("https://api.alpaca.markets")

      @broker_client_id = env("APCA_BROKER_CLIENT_ID")
      @broker_client_secret = env("APCA_BROKER_CLIENT_SECRET")
      @broker_key_id = env("APCA_BROKER_API_KEY_ID")
      @broker_secret_key = env("APCA_BROKER_API_SECRET_KEY")
      @broker_sandbox = env("APCA_BROKER_SANDBOX") != "false"

      @data_feed = env("APCA_DATA_FEED")&.to_sym

      @timeout = 30
      @open_timeout = 10
      @stream_timeout = 120
      @max_retries = 2
      @max_retry_interval = 60
      @logger = nil
      @user_agent = "alpaca-trade-api-ruby/#{VERSION}"
      @adapter = nil
    end

    private

    def env(*names)
      names.each do |name|
        value = ENV[name]
        return value unless value.nil? || value.empty?
      end
      nil
    end
  end
end
