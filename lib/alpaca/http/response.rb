# frozen_string_literal: true

module Alpaca
  module HTTP
    RateLimit = Data.define(:limit, :remaining, :reset_at) do
      def self.from_headers(headers)
        limit = headers["x-ratelimit-limit"]
        return if limit.nil?

        reset = headers["x-ratelimit-reset"]
        new(
          limit: limit.to_i,
          remaining: headers["x-ratelimit-remaining"]&.to_i,
          reset_at: reset && Time.at(reset.to_i)
        )
      end
    end

    class Response
      attr_reader :status, :headers, :body

      def initialize(status:, headers:, body:)
        @status = status
        @headers = headers
        @body = body
      end

      def success? = status.between?(200, 299)

      # Parsed JSON body. Non-integer numbers become BigDecimal.
      def data
        return @data if defined?(@data)

        @data = json? ? JSON.parse(body, decimal_class: BigDecimal) : nil
      end

      def json?
        return false if body.nil? || body.empty?

        content_type = headers["content-type"].to_s
        content_type.include?("json") || (content_type.empty? && body.lstrip.start_with?("{", "["))
      end

      def request_id = headers["x-request-id"]

      def rate_limit
        return @rate_limit if defined?(@rate_limit)

        @rate_limit = RateLimit.from_headers(headers)
      end
    end
  end
end
