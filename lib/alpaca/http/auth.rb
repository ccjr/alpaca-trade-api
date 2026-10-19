# frozen_string_literal: true

module Alpaca
  module HTTP
    # Authentication strategies. Each one adds its headers to a request and
    # knows which credentials to present when opening a stream.
    module Auth
      # Trading API / Market Data key pair, sent as APCA-API-* headers.
      class ApiKey
        attr_reader :key_id

        def initialize(key_id, secret_key)
          if blank?(key_id) || blank?(secret_key)
            raise ConfigurationError, "key_id and secret_key are required (or set APCA_API_KEY_ID / APCA_API_SECRET_KEY)"
          end

          @key_id = key_id
          @secret_key = secret_key
        end

        def apply(headers)
          headers["APCA-API-KEY-ID"] = @key_id
          headers["APCA-API-SECRET-KEY"] = @secret_key
        end

        def refreshable? = false

        def invalidate!
        end

        def stream_credentials = {key: @key_id, secret: @secret_key}

        def inspect = "#<#{self.class.name} key_id=#{@key_id.inspect}>"

        private

        def blank?(value) = value.nil? || value.to_s.empty?
      end

      # Alpaca Connect: an OAuth access token issued on behalf of a user.
      class Bearer
        def initialize(token)
          raise ConfigurationError, "an OAuth access token is required" if token.nil? || token.to_s.empty?

          @token = token
        end

        def apply(headers)
          headers["Authorization"] = "Bearer #{@token}"
        end

        def refreshable? = false

        def invalidate!
        end

        def stream_credentials = {key: "oauth", secret: @token}

        def inspect = "#<#{self.class.name}>"
      end

      # Legacy Broker API key pair, sent with HTTP Basic.
      class Basic
        def initialize(username, password)
          if username.nil? || password.nil? || username.to_s.empty? || password.to_s.empty?
            raise ConfigurationError, "broker key_id and secret_key are required"
          end

          @username = username
          @password = password
          @header = "Basic #{["#{username}:#{password}"].pack("m0")}"
        end

        def apply(headers)
          headers["Authorization"] = @header
        end

        def refreshable? = false

        def invalidate!
        end

        def stream_credentials = {key: @username, secret: @password}

        def inspect = "#<#{self.class.name} username=#{@username.inspect}>"
      end

      # OAuth2 client-credentials flow against authx.alpaca.markets (Broker API).
      # Tokens last ~15 minutes; they are cached, shared across threads and
      # refreshed shortly before they expire.
      class ClientCredentials
        ASSERTION_TYPE = "urn:ietf:params:oauth:client-assertion-type:jwt-bearer"
        REFRESH_MARGIN = 60

        # client_assertion: a String or a callable returning a freshly signed JWT
        # (private_key_jwt), used instead of client_secret.
        def initialize(client_id:, token_url:, client_secret: nil, client_assertion: nil, connection: nil)
          raise ConfigurationError, "client_id is required" if client_id.nil? || client_id.to_s.empty?
          if client_secret.nil? && client_assertion.nil?
            raise ConfigurationError, "client_secret or client_assertion is required"
          end

          @client_id = client_id
          @client_secret = client_secret
          @client_assertion = client_assertion
          @token_url = token_url
          @connection = connection || Faraday.new { |f| f.request :url_encoded }
          @mutex = Mutex.new
          @token = nil
          @expires_at = nil
        end

        def apply(headers)
          headers["Authorization"] = "Bearer #{token}"
        end

        def refreshable? = true

        def invalidate!
          @mutex.synchronize { @token = nil }
        end

        def stream_credentials = {key: "access_token", secret: token}

        def token
          @mutex.synchronize do
            fetch! if @token.nil? || now >= @expires_at - REFRESH_MARGIN
            @token
          end
        end

        def inspect = "#<#{self.class.name} client_id=#{@client_id.inspect}>"

        private

        def fetch!
          raw = @connection.post(@token_url, form)
          response = Response.new(status: raw.status, headers: raw.headers, body: raw.body)
          raise APIError.from_response(response) unless response.success?

          @token = response.data.fetch("access_token")
          @expires_at = now + response.data.fetch("expires_in", 900).to_i
        rescue Faraday::Error => e
          raise ConnectionError, "could not obtain broker access token: #{e.message}"
        end

        def form
          params = {grant_type: "client_credentials", client_id: @client_id}
          if @client_assertion
            assertion = @client_assertion.respond_to?(:call) ? @client_assertion.call : @client_assertion
            params.merge(client_assertion_type: ASSERTION_TYPE, client_assertion: assertion)
          else
            params.merge(client_secret: @client_secret)
          end
        end

        def now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end
end
