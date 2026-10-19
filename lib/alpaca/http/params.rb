# frozen_string_literal: true

module Alpaca
  module HTTP
    # Converts Ruby values into what Alpaca expects on the wire.
    module Params
      module_function

      # Query strings: nils dropped, arrays comma-joined, times as RFC 3339.
      def query(hash)
        return {} if hash.nil?

        hash.each_with_object({}) do |(key, value), out|
          next if value.nil?

          out[key.to_s] = value.is_a?(Array) ? value.map { |v| scalar(v) }.join(",") : scalar(value)
        end
      end

      # JSON bodies: nil values dropped from hashes, decimals sent as plain strings.
      def body(value)
        case value
        when Hash
          value.each_with_object({}) do |(key, v), out|
            out[key.to_s] = body(v) unless v.nil?
          end
        when Array then value.map { |v| body(v) }
        when BigDecimal, Time, DateTime, Date, Symbol then scalar(value)
        else value
        end
      end

      def scalar(value)
        case value
        when BigDecimal then value.to_s("F").delete_suffix(".0")
        when DateTime then time(value.to_time)
        when Time then time(value)
        when Date then value.iso8601
        when Symbol then value.to_s
        else value
        end
      end

      def time(value)
        value = value.utc
        value.iso8601(value.nsec.zero? ? 0 : 9)
      end

      # Escapes one path segment ("BTC/USD" -> "BTC%2FUSD").
      def segment(value)
        URI.encode_www_form_component(scalar(value).to_s).gsub("+", "%20")
      end
    end
  end
end
