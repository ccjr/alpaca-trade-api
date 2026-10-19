# frozen_string_literal: true

module Alpaca
  module Streaming
    # Order updates for a Trading API account (wss://{paper-}api.alpaca.markets/stream).
    #
    #   updates = Alpaca::Streaming::TradeUpdates.new                 # env credentials, paper
    #   updates.on(:fill, :partial_fill) { |event| puts "#{event.order.symbol} #{event.qty} @ #{event.price}" }
    #   updates.on_update { |event| ... }                              # every event
    #   updates.run
    #
    # Broker partners receive the same events for all accounts through
    # broker.events.trades (SSE).
    class TradeUpdates < Stream
      LIVE_URL = "wss://api.alpaca.markets/stream"
      PAPER_URL = "wss://paper-api.alpaca.markets/stream"

      def initialize(key_id: nil, secret_key: nil, oauth_token: nil, paper: nil, url: nil,
        config: Alpaca.configuration, **options)
        paper = config.paper if paper.nil?
        oauth_token ||= config.oauth_token unless key_id
        auth = if oauth_token
          HTTP::Auth::Bearer.new(oauth_token)
        else
          HTTP::Auth::ApiKey.new(key_id || config.key_id, secret_key || config.secret_key)
        end
        super(url: url || (paper ? PAPER_URL : LIVE_URL), auth: auth, logger: config.logger, **options)
      end

      # Handles every trade update.
      def on_update(&block) = add_handler(:update, &block)

      # Handles specific events: :new, :fill, :partial_fill, :canceled, :expired,
      # :replaced, :rejected, :done_for_day, ...
      def on(*events, &block)
        events = events.map(&:to_sym)
        on_update { |event| block.call(event) if events.include?(event.event) }
      end

      private

      def authenticate(socket)
        send_message(auth_message, socket: socket)
        while (frame = socket.read)
          message = decode(*frame)
          next unless message["stream"] == "authorization"

          data = message["data"] || {}
          return if data["status"] == "authorized"

          raise Streaming::AuthenticationError, "trade_updates authentication failed: #{data.inspect}"
        end
        raise ConnectionError, "connection closed during authentication"
      end

      def auth_message
        if @auth.is_a?(HTTP::Auth::Bearer)
          {action: "authenticate", data: {oauth_token: @auth.stream_credentials[:secret]}}
        else
          {action: "auth", **@auth.stream_credentials}
        end
      end

      def on_open(socket)
        send_message({action: "listen", data: {streams: ["trade_updates"]}}, socket: socket)
      end

      def handle(message)
        case message["stream"]
        when "trade_updates" then emit(:update, TradeEvent.build(message["data"]))
        when "listening" then log("listening to #{message.dig("data", "streams").inspect}")
        when "authorization"
          emit(:error, Streaming::AuthenticationError.new("unauthorized: #{message["data"].inspect}"))
        end
      end

      # The paper endpoint sends JSON in binary frames.
      def decode(payload, _binary) = JSON.parse(payload.dup.force_encoding(Encoding::UTF_8), decimal_class: BigDecimal)
    end
  end
end
