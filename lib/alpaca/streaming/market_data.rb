# frozen_string_literal: true

module Alpaca
  module MarketData
    # Stream-only stock messages.
    class TradingStatus < Record
      field :timestamp, "t", :time
      field :status_code, "sc", :string
      field :status_message, "sm", :string
      field :reason_code, "rc", :string
      field :reason_message, "rm", :string
      field :tape, "z", :string
    end

    # Limit Up / Limit Down price bands.
    class LULD < Record
      field :timestamp, "t", :time
      field :limit_up_price, "u", :decimal
      field :limit_down_price, "d", :decimal
      field :indicator, "i", :string
      field :tape, "z", :string
    end

    class TradeCorrection < Record
      field :timestamp, "t", :time
      field :exchange, "x", :string
      field :original_id, "oi", :integer
      field :original_price, "op", :decimal
      field :original_size, "os", :integer
      field :original_conditions, "oc", :raw
      field :corrected_id, "ci", :integer
      field :corrected_price, "cp", :decimal
      field :corrected_size, "cs", :integer
      field :corrected_conditions, "cc", :raw
      field :tape, "z", :string
    end

    # A cancelled ("C") or erroneous ("E") trade.
    class TradeCancel < Record
      field :timestamp, "t", :time
      field :id, "i", :integer
      field :exchange, "x", :string
      field :price, "p", :decimal
      field :size, "s", :integer
      field :action, "a", :string
      field :tape, "z", :string
    end

    class Imbalance < Record
      field :timestamp, "t", :time
      field :price, "p", :decimal
      field :tape, "z", :string
    end
  end

  module Streaming
    # Rejected subscription or other server-side stream error (codes 400-500).
    class StreamError < Alpaca::Error
      attr_reader :code

      def initialize(message, code: nil)
        @code = code
        super("#{message} (code #{code})")
      end
    end

    # Real-time market data over WebSocket: stocks, crypto, options and news.
    #
    #   stream = Alpaca::Streaming::MarketData.stocks(feed: :sip)
    #   stream.on_trade("AAPL", "MSFT") { |trade| puts "#{trade.symbol} #{trade.price}" }
    #   stream.on_bar("*") { |bar| ... }
    #   stream.run                              # blocks; reconnects and resubscribes
    #
    #   Alpaca::Streaming::MarketData.crypto.on_orderbook("BTC/USD") { |book| ... }
    #   Alpaca::Streaming::MarketData.options(feed: :opra).on_quote("AAPL270115C00190000") { |q| ... }
    #   Alpaca::Streaming::MarketData.news.on_news("*") { |article| ... }
    #   Alpaca::Streaming::MarketData.test.on_trade("FAKEPACA") { |t| ... }   # always-on test feed
    #
    # Subscriptions can change while running, from any thread:
    #   stream.subscribe(quotes: %w[NVDA]); stream.unsubscribe(trades: %w[MSFT])
    class MarketData < Stream
      HOST = "wss://stream.data.alpaca.markets"
      SANDBOX_HOST = "wss://stream.data.sandbox.alpaca.markets"

      Channel = Data.define(:name, :type, :record, :subscribable)

      def self.channel(name, type, record, subscribable: true) = Channel.new(name, type, record, subscribable)

      MD = ::Alpaca::MarketData
      STOCK_CHANNELS = {
        trades: channel("trades", "t", MD::Trade),
        quotes: channel("quotes", "q", MD::Quote),
        bars: channel("bars", "b", MD::Bar),
        updated_bars: channel("updatedBars", "u", MD::Bar),
        daily_bars: channel("dailyBars", "d", MD::Bar),
        statuses: channel("statuses", "s", MD::TradingStatus),
        lulds: channel("lulds", "l", MD::LULD),
        imbalances: channel("imbalances", "i", MD::Imbalance),
        # Delivered automatically with trades.
        corrections: channel("corrections", "c", MD::TradeCorrection, subscribable: false),
        cancel_errors: channel("cancelErrors", "x", MD::TradeCancel, subscribable: false)
      }.freeze
      CRYPTO_CHANNELS = {
        trades: channel("trades", "t", MD::CryptoTrade),
        quotes: channel("quotes", "q", MD::CryptoQuote),
        bars: channel("bars", "b", MD::CryptoBar),
        updated_bars: channel("updatedBars", "u", MD::CryptoBar),
        daily_bars: channel("dailyBars", "d", MD::CryptoBar),
        orderbooks: channel("orderbooks", "o", MD::Orderbook)
      }.freeze
      OPTION_CHANNELS = {
        trades: channel("trades", "t", MD::OptionTrade),
        quotes: channel("quotes", "q", MD::OptionQuote)
      }.freeze
      NEWS_CHANNELS = {news: channel("news", "n", MD::NewsArticle)}.freeze

      HANDLERS = {
        trade: :trades, quote: :quotes, bar: :bars, updated_bar: :updated_bars, daily_bar: :daily_bars,
        status: :statuses, luld: :lulds, imbalance: :imbalances, correction: :corrections,
        cancel_error: :cancel_errors, orderbook: :orderbooks, news: :news
      }.freeze

      # Stocks: feed is :iex, :sip, :delayed_sip, :boats, :overnight or :otc.
      def self.stocks(feed: nil, config: Alpaca.configuration, **)
        new(path: "v2/#{feed || config.data_feed || :iex}", channels: STOCK_CHANNELS, config: config, **)
      end

      def self.crypto(loc: :us, **) = new(path: "v1beta3/crypto/#{loc}", channels: CRYPTO_CHANNELS, **)

      # Options: feed is :indicative or :opra. Requires the msgpack gem.
      def self.options(feed: :indicative, **)
        new(path: "v1beta1/#{feed}", channels: OPTION_CHANNELS, codec: :msgpack, **)
      end

      def self.news(**) = new(path: "v1beta1/news", channels: NEWS_CHANNELS, **)

      # Always-on test feed (symbol "FAKEPACA"), even outside market hours.
      def self.test(**) = new(path: "v2/test", channels: STOCK_CHANNELS, **)

      attr_reader :channels

      # auth: any Alpaca::HTTP::Auth strategy (e.g. a Broker client's connection.auth).
      def initialize(path:, channels:, codec: :json, key_id: nil, secret_key: nil, oauth_token: nil, auth: nil,
        sandbox: false, url: nil, config: Alpaca.configuration, **options)
        @channels = channels
        @codec = (codec == :msgpack) ? MsgpackCodec.new : nil
        @subscriptions = Hash.new { |hash, key| hash[key] = [] }
        unless auth
          oauth_token ||= config.oauth_token unless key_id
          auth = if oauth_token
            HTTP::Auth::Bearer.new(oauth_token)
          else
            HTTP::Auth::ApiKey.new(key_id || config.key_id, secret_key || config.secret_key)
          end
        end
        super(url: url || "#{sandbox ? SANDBOX_HOST : HOST}/#{path}", auth: auth, logger: config.logger, **options)
      end

      HANDLERS.each do |handler, channel|
        # Registers a handler and subscribes to the given symbols ("*" for all).
        define_method(:"on_#{handler}") do |*symbols, &block|
          raise ArgumentError, "#{handler} is not available on this stream" unless channels.key?(channel)
          raise ArgumentError, "a block is required" unless block

          symbols = symbols.flatten.map(&:to_s)
          add_handler(channels.fetch(channel).type) { |record| block.call(record) if match?(record, symbols) }
          subscribe(channel => symbols) unless symbols.empty?
          self
        end
      end

      # Server confirmations: a Hash of channel => symbols currently subscribed.
      def on_subscription(&block) = add_handler(:subscription, &block)

      # Adds symbols per channel: subscribe(trades: %w[AAPL], quotes: ["*"]).
      def subscribe(**request) = change(:subscribe, request)

      def unsubscribe(**request) = change(:unsubscribe, request)

      # Symbols per channel this client will (re)subscribe to on connect.
      def subscriptions = @mutex.synchronize { @subscriptions.transform_values(&:dup) }

      private

      def headers
        @codec ? {"Content-Type" => "application/msgpack"} : {}
      end

      def change(action, request)
        message = {"action" => action.to_s}
        @mutex.synchronize do
          request.each do |channel, symbols|
            spec = channels.fetch(channel.to_sym) { raise ArgumentError, "unknown channel #{channel.inspect}" }
            next unless spec.subscribable

            symbols = Array(symbols).map(&:to_s)
            list = @subscriptions[spec.name]
            (action == :subscribe) ? list.concat(symbols - list) : list.replace(list - symbols)
            message[spec.name] = symbols
          end
        end
        send_message(message) if message.size > 1
        self
      end

      def authenticate(socket)
        credentials = @auth.stream_credentials
        send_message({action: "auth", key: credentials[:key], secret: credentials[:secret]}, socket: socket)
        while (frame = socket.read)
          messages = Array(decode(*frame))
          error = messages.find { |message| message["T"] == "error" }
          raise control_error(error) if error
          return if messages.any? { |message| message["T"] == "success" && message["msg"] == "authenticated" }
        end
        raise ConnectionError, "connection closed during authentication"
      end

      def on_open(socket)
        request = @mutex.synchronize { @subscriptions.reject { |_, symbols| symbols.empty? }.transform_values(&:dup) }
        send_message({"action" => "subscribe", **request}, socket: socket) unless request.empty?
      end

      def handle(messages)
        Array(messages).each do |message|
          case (type = message["T"])
          when "subscription" then emit(:subscription, message.except("T"))
          when "error" then emit(:error, control_error(message))
          when "success" then nil
          else dispatch(type, message)
          end
        end
      end

      def dispatch(type, message)
        spec = channels.each_value.find { |channel| channel.type == type }
        return unless spec

        record = if spec.record < ::Alpaca::MarketData::Record
          spec.record.new(message, symbol: message["S"])
        else
          spec.record.new(message)
        end
        emit(type, record)
      end

      def match?(record, symbols)
        return true if symbols.empty? || symbols.include?("*")

        names = record.is_a?(::Alpaca::MarketData::Record) ? [record.symbol] : Array(record[:symbols])
        names.any? { |name| symbols.include?(name.to_s) }
      end

      def control_error(message)
        code = message["code"].to_i
        text = message["msg"].to_s
        case code
        when 402 then Streaming::AuthenticationError.new("market data stream: #{text}")
        when 406 then ConnectionLimitError.new("#{text} (code 406): close other connections or upgrade the subscription")
        else StreamError.new(text, code: code)
        end
      end

      def send_message(message, socket: @socket)
        return super unless @codec

        socket&.write(@codec.encode(message), binary: true)
      end

      def decode(payload, binary)
        return @codec.decode(payload) if @codec && binary

        JSON.parse(payload.dup.force_encoding(Encoding::UTF_8), decimal_class: BigDecimal)
      end
    end

    # MessagePack codec for the options stream (timestamps arrive as msgpack Timestamp extensions).
    class MsgpackCodec
      def initialize
        require "msgpack"
        @factory = MessagePack::Factory.new
        @factory.register_type(-1, Time, packer: MessagePack::Time::Packer, unpacker: MessagePack::Time::Unpacker)
      rescue LoadError => e
        raise MissingDependencyError, "the options stream needs the msgpack gem (add `gem \"msgpack\"`): #{e.message}"
      end

      def encode(message) = @factory.dump(JSON.parse(JSON.generate(message)))

      def decode(payload) = @factory.load(payload)
    end
  end
end
