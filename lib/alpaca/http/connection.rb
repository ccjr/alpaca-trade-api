# frozen_string_literal: true

module Alpaca
  module HTTP
    # One persistent Faraday connection per client. Thread-safe.
    class Connection
      IDEMPOTENT_METHODS = %i[get head delete put options].freeze
      RETRY_STATUSES = [429, 502, 503, 504].freeze
      RETRY_EXCEPTIONS = [
        Errno::ETIMEDOUT, Errno::ECONNRESET, Timeout::Error,
        Faraday::TimeoutError, Faraday::ConnectionFailed, Faraday::RetriableResponse
      ].freeze

      attr_reader :base_url, :auth

      def initialize(base_url:, auth:, config: Alpaca.configuration, &faraday)
        @base_url = base_url
        @auth = auth
        @config = config
        @faraday = build(faraday)
      end

      # Performs a request and returns an HTTP::Response, raising APIError
      # subclasses for non-2xx statuses.
      def request(method, path, query: nil, body: nil, headers: nil, idempotency_key: nil)
        attempted_refresh = false
        begin
          response = perform(method, path, query, body, headers, idempotency_key)
          raise APIError.from_response(response) unless response.success?

          response
        rescue AuthenticationError
          raise if attempted_refresh || !auth.refreshable?

          attempted_refresh = true
          auth.invalidate!
          retry
        end
      end

      # Streams a long-lived GET (Server-Sent Events), yielding raw body chunks.
      # Non-2xx responses raise APIError subclasses like #request.
      def stream(path, query: nil, &on_chunk)
        attempted_refresh = false
        begin
          perform_stream(path, query, on_chunk)
        rescue AuthenticationError
          raise if attempted_refresh || !auth.refreshable?

          attempted_refresh = true
          auth.invalidate!
          retry
        end
      end

      def inspect = "#<#{self.class.name} #{base_url}>"

      private

      def perform_stream(path, query, on_chunk)
        status = nil
        error_body = +""
        raw = @faraday.get(path.delete_prefix("/")) do |req|
          req.params.update(Params.query(query)) if query
          auth.apply(req.headers)
          req.headers["Accept"] = "text/event-stream"
          req.options.read_timeout = @config.stream_timeout
          # EventStream owns reconnection because it can resume from the last
          # event id. Retrying here would repeat the original request after
          # chunks have already been yielded and deliver duplicate events.
          req.options.context = (req.options.context || {}).merge(alpaca_stream: true)
          req.options.on_data = proc do |chunk, _bytes, env|
            status ||= env&.status
            (status.nil? || status.between?(200, 299)) ? on_chunk.call(chunk) : error_body << chunk
          end
        end
        status ||= raw.status
        return if status.between?(200, 299)

        body = error_body.empty? ? raw.body : error_body
        raise APIError.from_response(Response.new(status: status, headers: raw.headers, body: body))
      rescue Faraday::TimeoutError => e
        raise TimeoutError, e.message
      rescue Faraday::ConnectionFailed, Faraday::SSLError => e
        raise ConnectionError, e.message
      end

      def perform(method, path, query, body, headers, idempotency_key)
        raw = @faraday.run_request(method, path.delete_prefix("/"), nil, nil) do |req|
          req.params.update(Params.query(query)) if query
          auth.apply(req.headers)
          req.headers["Idempotency-Key"] = idempotency_key if idempotency_key
          req.headers.update(headers) if headers
          unless body.nil?
            req.headers["Content-Type"] = "application/json"
            req.body = JSON.generate(Params.body(body))
          end
        end
        Response.new(status: raw.status, headers: raw.headers, body: raw.body)
      rescue Faraday::TimeoutError => e
        raise TimeoutError, e.message
      rescue Faraday::ConnectionFailed, Faraday::SSLError => e
        raise ConnectionError, e.message
      end

      def build(customize)
        Faraday.new(
          url: base_url.end_with?("/") ? base_url : "#{base_url}/",
          headers: {"User-Agent" => @config.user_agent, "Accept" => "application/json"},
          request: {timeout: @config.timeout, open_timeout: @config.open_timeout}
        ) do |f|
          f.request :retry, retry_options if @config.max_retries.to_i.positive?
          f.response :logger, @config.logger, headers: false, bodies: false, log_level: :debug if @config.logger
          f.adapter(@config.adapter || preferred_adapter)
          customize&.call(f)
        end
      end

      def retry_options
        {
          max: @config.max_retries,
          interval: 0.5,
          interval_randomness: 0.5,
          backoff_factor: 2,
          max_interval: @config.max_retry_interval,
          # Use retry_if for every method so streaming GETs can opt out after
          # they have started yielding data.
          methods: [],
          retry_statuses: RETRY_STATUSES,
          exceptions: RETRY_EXCEPTIONS,
          # Non-idempotent requests are retried only when nothing could have been
          # applied (429) or the server de-duplicates them (Idempotency-Key).
          retry_if: lambda { |env, _exception|
            !env.request.context&.[](:alpaca_stream) &&
              (IDEMPOTENT_METHODS.include?(env.method) || env.status == 429 ||
                env.request_headers.key?("Idempotency-Key"))
          },
          rate_limit_reset_header: "X-RateLimit-Reset",
          header_parser_block: method(:seconds_until)
        }
      end

      # Retry-After is seconds or an HTTP date; X-RateLimit-Reset is a Unix timestamp.
      def seconds_until(value)
        return if value.nil? || value.to_s.empty?

        if value.to_s.match?(/\A\d+(\.\d+)?\z/)
          number = value.to_f
          (number > 1_000_000_000) ? [number - Time.now.to_f, 0].max : number
        else
          [Time.httpdate(value) - Time.now, 0].max
        end
      rescue ArgumentError
        nil
      end

      def preferred_adapter
        defined?(Faraday::Adapter::NetHttpPersistent) ? :net_http_persistent : Faraday.default_adapter
      end
    end
  end
end
