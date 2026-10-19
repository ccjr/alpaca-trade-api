# frozen_string_literal: true

module Alpaca
  module Streaming
    # Raised when the server rejects the credentials; not retried.
    class AuthenticationError < Alpaca::AuthenticationError
      def initialize(message) = super(message, status: 401)
    end

    # Too many concurrent connections for the subscription (code 406); not retried.
    class ConnectionLimitError < Alpaca::Error; end

    # Base WebSocket stream: connect, authenticate, (re)subscribe, dispatch,
    # reconnect with backoff. Subclasses implement the protocol hooks.
    class Stream
      MAX_BACKOFF = 30

      attr_reader :url

      def initialize(url:, auth:, transport: nil, reconnect: true, max_reconnects: nil, logger: Alpaca.configuration.logger)
        @url = url
        @auth = auth
        @transport = transport || AsyncTransport.new
        @reconnect = reconnect
        @max_reconnects = max_reconnects
        @logger = logger
        @handlers = Hash.new { |hash, key| hash[key] = [] }
        @mutex = Mutex.new
        @socket = nil
        @stopped = false
      end

      # Called with every Alpaca::Error raised while streaming (before reconnecting).
      def on_error(&block) = add_handler(:error, &block)

      # Called after each successful (re)connection and authentication.
      def on_connect(&block) = add_handler(:connect, &block)

      # Called whenever the connection drops.
      def on_disconnect(&block) = add_handler(:disconnect, &block)

      # Connects and blocks, dispatching messages to handlers, until #stop is
      # called or a non-retryable error occurs.
      def run
        @stopped = false
        failures = 0
        until @stopped
          begin
            connect_once { failures = 0 }
          rescue Streaming::AuthenticationError, ConnectionLimitError => e
            emit(:error, e)
            raise
          rescue Alpaca::Error, IOError, SystemCallError => e
            emit(:error, e)
          end
          emit(:disconnect)
          break if @stopped || !retry?(failures)

          failures += 1
          sleep backoff(failures)
        end
        self
      end

      # Stops the stream; #run returns shortly after. Safe from any thread or handler.
      def stop
        @stopped = true
        @mutex.synchronize { @socket&.close }
      end

      def running? = !@socket.nil?

      def inspect = "#<#{self.class.name} #{url}>"

      private

      # Protocol hooks.
      def headers = {}

      def authenticate(socket) = raise(NotImplementedError)

      def on_open(socket) = nil

      def handle(payload) = raise(NotImplementedError)

      def connect_once
        @transport.connect(url, headers: headers) do |socket|
          @mutex.synchronize { @socket = socket }
          authenticate(socket)
          yield
          emit(:connect)
          on_open(socket)
          while (frame = socket.read)
            handle(decode(*frame))
            break if @stopped
          end
        ensure
          @mutex.synchronize { @socket = nil }
        end
      end

      def send_message(message, socket: @socket)
        socket&.write(JSON.generate(message))
      end

      def decode(payload, _binary) = JSON.parse(payload, decimal_class: BigDecimal)

      def add_handler(event, &block)
        raise ArgumentError, "a block is required" unless block

        @mutex.synchronize { @handlers[event] << block }
        self
      end

      def emit(event, *args)
        @handlers[event].each { |handler| handler.call(*args) } if @handlers.key?(event)
      end

      def retry?(failures) = @reconnect && (@max_reconnects.nil? || failures < @max_reconnects)

      def backoff(failures) = [2**(failures - 1), MAX_BACKOFF].min + rand * 0.5

      def log(message) = @logger&.info("[alpaca stream] #{message}")
    end
  end
end
