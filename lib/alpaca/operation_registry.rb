# frozen_string_literal: true

module Alpaca
  # Maps OpenAPI operationIds to the Ruby methods that implement them, so
  # `rake openapi:coverage` can report which documented endpoints are missing.
  module OperationRegistry
    Entry = Data.define(:api, :operation_id, :implementation)

    @entries = []
    @skipped = {}

    class << self
      attr_reader :entries

      def register(api, operation_id, implementation)
        @entries << Entry.new(api: api.to_sym, operation_id: operation_id, implementation: implementation)
      end

      # Documents an operation that is deliberately not implemented.
      def skip(api, operation_id, reason)
        @skipped[[api.to_sym, operation_id]] = reason
      end

      attr_reader :skipped

      def implemented?(api, operation_id)
        @entries.any? { |e| e.api == api.to_sym && e.operation_id == operation_id }
      end

      def for_api(api) = @entries.select { |e| e.api == api.to_sym }
    end
  end
end
