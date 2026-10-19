# frozen_string_literal: true

module Alpaca
  module Streaming
    # Default WebSocket transport, built on async-websocket. A transport opens a
    # connection and yields a socket responding to:
    #   read  -> [payload String, binary Boolean] or nil when closed
    #   write(payload, binary: false)  (safe to call from any thread)
    #   close
    class AsyncTransport
      def self.load!
        require "async"
        require "async/http/endpoint"
        require "async/websocket/client"
      rescue LoadError => e
        raise MissingDependencyError,
          "Alpaca streaming needs the async-websocket gem (add `gem \"async-websocket\"` to your Gemfile): #{e.message}"
      end

      def initialize
        self.class.load!
      end

      # Runs inside an Async reactor (started if needed) until the block returns.
      def connect(url, headers: {})
        Sync do |task|
          endpoint = Async::HTTP::Endpoint.parse(url, alpn_protocols: Async::HTTP::Protocol::HTTP11.names)
          Async::WebSocket::Client.connect(endpoint, headers: headers.to_a) do |connection|
            socket = Socket.new(connection, task)
            begin
              yield socket
            ensure
              socket.shutdown
            end
          end
        end
      end

      # Wraps an async-websocket connection; writes from other threads are
      # queued and flushed by a task inside the reactor.
      class Socket
        def initialize(connection, task)
          @connection = connection
          @outbox = Thread::Queue.new
          @writer = task.async do
            while (item = @outbox.pop)
              break @connection.close if item == :close

              payload, binary = item
              binary ? @connection.send_binary(payload) : @connection.send_text(payload)
              @connection.flush
            end
          end
        end

        def read
          message = @connection.read
          return unless message

          [message.buffer, message.is_a?(Protocol::WebSocket::BinaryMessage)]
        end

        def write(payload, binary: false)
          @outbox << [payload, binary] unless @outbox.closed?
        end

        # Thread-safe: the reactor closes the connection, which ends #read.
        def close
          @outbox << :close unless @outbox.closed?
        end

        def shutdown
          @outbox.close
          @writer.stop
        end
      end
    end
  end
end
