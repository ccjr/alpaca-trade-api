# frozen_string_literal: true

require "json"

module Alpaca
  # Compares the vendored OpenAPI specs (openapi/*.json) with the operations
  # registered by resources. Development tool; not loaded by `require "alpaca"`.
  class OpenAPICoverage
    SPECS = {
      trading: "trading-api.json",
      broker: "broker-api.json",
      market_data: "market-data-api.json"
    }.freeze
    URLS = {
      trading: "https://docs.alpaca.markets/openapi/trading-api.json",
      broker: "https://docs.alpaca.markets/openapi/broker-api.json",
      market_data: "https://docs.alpaca.markets/openapi/market-data-api.json"
    }.freeze
    VERBS = %w[get post put patch delete].freeze

    Operation = Data.define(:api, :id, :verb, :path)

    def initialize(dir: File.expand_path("../../openapi", __dir__), registry: OperationRegistry)
      @dir = dir
      @registry = registry
    end

    def operations(api)
      spec = JSON.parse(File.read(File.join(@dir, SPECS.fetch(api))))
      spec.fetch("paths").flat_map do |path, item|
        item.filter_map do |verb, op|
          next unless VERBS.include?(verb)

          Operation.new(api: api, id: op["operationId"], verb: verb.upcase, path: path)
        end
      end
    end

    def missing(api)
      operations(api).reject { |op| @registry.implemented?(api, op.id) || @registry.skipped.key?([api, op.id]) }
    end

    # Registered ids that no longer exist in the spec (renamed or removed upstream).
    def stale(api)
      known = operations(api).map(&:id)
      @registry.for_api(api).reject { |entry| known.include?(entry.operation_id) }
    end

    def report(io = $stdout)
      ok = true
      SPECS.each_key do |api|
        ops = operations(api)
        missing = missing(api)
        stale = stale(api)
        skipped = ops.count { |op| @registry.skipped.key?([api, op.id]) }
        io.puts format("%-12s %3d operations, %3d implemented, %3d skipped, %3d missing",
          api, ops.size, ops.size - missing.size - skipped, skipped, missing.size)
        missing.each { |op| io.puts "    missing  #{op.verb.ljust(6)} #{op.path}  (#{op.id})" }
        stale.each { |e| io.puts "    stale    #{e.operation_id} -> #{e.implementation}" }
        ok &&= missing.empty? && stale.empty?
      end
      ok
    end
  end
end
