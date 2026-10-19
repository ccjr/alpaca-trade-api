# frozen_string_literal: true

module Alpaca
  class Error < StandardError; end

  # Missing or invalid client configuration (credentials, hosts, options).
  class ConfigurationError < Error; end

  # The request never produced an HTTP response.
  class ConnectionError < Error; end

  class TimeoutError < ConnectionError; end

  # An order submission failed without a response, so it may or may not have
  # been accepted. Look it up with orders.find_by_client_order_id(client_order_id).
  class UnknownOrderStateError < ConnectionError
    attr_reader :client_order_id

    def initialize(message = nil, client_order_id: nil)
      @client_order_id = client_order_id
      super("#{message} (order state unknown; look it up by client_order_id #{client_order_id.inspect})")
    end
  end

  # Optional streaming dependency (async-websocket, msgpack) is not installed.
  class MissingDependencyError < Error; end

  # The API answered with a non-2xx status.
  class APIError < Error
    attr_reader :status, :code, :body, :response

    def self.from_response(response)
      data = parse(response)
      api_message = data["message"] if data.is_a?(Hash)
      api_message ||= response.body.to_s[0, 500] unless response.body.to_s.empty?
      code = data["code"] if data.is_a?(Hash)

      for_status(response.status).new(
        api_message, status: response.status, code: code, body: data || response.body, response: response
      )
    end

    def self.for_status(status)
      STATUS_CLASSES.fetch(status) { (status >= 500) ? ServerError : APIError }
    end

    def self.parse(response)
      response.data
    rescue JSON::ParserError
      nil
    end
    private_class_method :parse

    def initialize(api_message = nil, status: nil, code: nil, body: nil, response: nil)
      @api_message = api_message
      @status = status
      @code = code
      @body = body
      @response = response
      super(build_message)
    end

    # The message as returned by Alpaca, without status/code decoration.
    attr_reader :api_message

    def request_id = response&.request_id

    private

    def build_message
      details = ["HTTP #{status}", code && "code #{code}", request_id && "request #{request_id}"].compact
      "#{@api_message || "request failed"} (#{details.join(", ")})"
    end
  end

  class BadRequestError < APIError; end

  class AuthenticationError < APIError; end

  # Includes insufficient buying power (code 40310000) and other permission failures.
  class ForbiddenError < APIError; end

  class NotFoundError < APIError; end

  class ConflictError < APIError; end

  class UnprocessableEntityError < APIError; end

  class RateLimitError < APIError
    # Seconds until the rate-limit window resets, when Alpaca says so.
    def retry_after
      reset_at = response&.rate_limit&.reset_at
      return [reset_at - Time.now, 0].max if reset_at

      value = response&.headers&.[]("retry-after")
      value&.to_f
    end
  end

  class ServerError < APIError; end

  class APIError
    STATUS_CLASSES = {
      400 => BadRequestError,
      401 => AuthenticationError,
      403 => ForbiddenError,
      404 => NotFoundError,
      409 => ConflictError,
      422 => UnprocessableEntityError,
      429 => RateLimitError
    }.freeze
  end
end
