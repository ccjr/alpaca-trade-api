# frozen_string_literal: true

module Alpaca
  # Server-Sent Events (text/event-stream) parsing and consumption. Used by the
  # Trading, Broker and Market Data event endpoints; needs no extra gems.
  module SSE
    Message = Data.define(:id, :event, :data)

    # Incremental parser: feed it chunks, it yields complete messages.
    # Comments (":heartbeat") are skipped.
    class Parser
      def initialize
        @buffer = +""
        reset
      end

      def feed(chunk)
        @buffer << chunk.to_s.encode("UTF-8", invalid: :replace, undef: :replace)
        while (index = @buffer.index("\n"))
          line = @buffer.slice!(0..index).chomp.delete_suffix("\r")
          line.empty? ? dispatch { |message| yield message } : field(line)
        end
      end

      private

      def field(line)
        return if line.start_with?(":")

        name, value = line.split(":", 2)
        value = value&.delete_prefix(" ").to_s
        case name
        when "data" then @data << value
        when "id" then @id = value
        when "event" then @event = value
        end
      end

      def dispatch
        yield Message.new(id: @id, event: @event, data: @data.join("\n")) unless @data.empty?
        reset
      end

      def reset
        @data = []
        @id = nil
        @event = nil
      end
    end
  end

  # A lazy, resumable stream of events. Iterating opens the HTTP stream; when the
  # connection drops it reconnects with exponential backoff and resumes after the
  # last event seen. Streams bounded by `until`/`until_id`/`until_ulid` end on
  # their own and are not reconnected.
  #
  #   broker.events.trades(since: Time.now - 3600).each { |event| ... }   # replay, then live
  #   broker.events.journals(since: "2026-10-01", until: "2026-10-02").to_a
  class EventStream
    include Enumerable

    BOUNDS = %w[until until_id until_ulid].freeze
    MAX_BACKOFF = 30

    # resume: :since_id (ULID event_id), :since_ulid (legacy integer ids with
    # event_ulid) or :last_event_id. Each payload item is built with `model`.
    def initialize(connection, path, query: {}, model: Event, resume: :since_id, reconnect: nil, max_reconnects: nil)
      @connection = connection
      @path = path
      @query = query.transform_keys(&:to_s)
      @model = model
      @resume = resume
      @reconnect = reconnect.nil? ? (@query.keys & BOUNDS).empty? : reconnect
      @max_reconnects = max_reconnects
    end

    def each(&block)
      return enum_for(:each) unless block

      last_id = nil
      failures = 0
      loop do
        begin
          parser = SSE::Parser.new
          @connection.stream(@path, query: resume_query(last_id)) do |chunk|
            parser.feed(chunk) do |message|
              parse(message).each do |event|
                failures = 0
                last_id = resume_id(event) || last_id
                block.call(event)
              end
            end
          end
        rescue ConnectionError, ServerError, RateLimitError
          raise unless retry_stream?(failures)
        end
        break unless retry_stream?(failures)

        failures += 1
        sleep backoff(failures)
      end
      self
    end

    def reconnect? = @reconnect

    def inspect = "#<#{self.class.name} #{@path}>"

    # Builds models from a raw SSE message (payloads may be one object or an array).
    def parse(message)
      data = JSON.parse(message.data, decimal_class: BigDecimal)
      Array(data.is_a?(Array) ? data : [data]).map { |item| @model.build(item) }
    rescue JSON::ParserError
      []
    end

    private

    def retry_stream?(failures) = @reconnect && (@max_reconnects.nil? || failures < @max_reconnects)

    def backoff(failures) = [2**(failures - 1), MAX_BACKOFF].min + rand * 0.5

    def resume_query(last_id)
      return @query unless last_id

      query = @query.except("since", "since_id", "since_ulid", "last_event_id")
      query.merge(@resume.to_s => last_id)
    end

    def resume_id(event)
      (@resume == :since_ulid) ? event["event_ulid"] : event["event_id"]
    end
  end
end
