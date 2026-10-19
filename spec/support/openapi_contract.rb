# frozen_string_literal: true

require "json"

# Checks every HTTP request made during the suite against the vendored OpenAPI
# specs: the path/verb must be documented, and query and JSON body keys must be
# parameters of that operation. Catches typos and drift without live calls.
module OpenAPIContract
  HOSTS = {
    "paper-api.alpaca.markets" => :trading,
    "api.alpaca.markets" => :trading,
    "broker-api.sandbox.alpaca.markets" => :broker,
    "broker-api.alpaca.markets" => :broker,
    "data.alpaca.markets" => :market_data,
    "data.sandbox.alpaca.markets" => :market_data
  }.freeze
  FILES = {trading: "trading-api.json", broker: "broker-api.json", market_data: "market-data-api.json"}.freeze

  Operation = Struct.new(:id, :verb, :regex, :query_params, :body_keys, :path_template)

  class << self
    def violations = (@violations ||= [])

    def check(request)
      api = HOSTS[request.uri.host]
      return unless api

      verb = request.method.to_s
      path = request.uri.path
      candidates = operations(api).select { |op| op.verb == verb && op.regex.match?(path) }
      if candidates.empty?
        violations << "#{api}: #{verb.upcase} #{path} is not a documented operation"
        return
      end
      # Prefer literal matches over templated ones (e.g. /assets/entry-requirements vs /assets/{id}).
      op = candidates.min_by { |o| o.path_template.count("{") }

      query_keys = URI.decode_www_form(request.uri.query.to_s).map(&:first)
      unknown = query_keys - op.query_params
      violations << "#{api}: #{op.id} has no query params #{unknown.inspect}" if unknown.any?

      if request.body && !request.body.empty? && op.body_keys
        body = JSON.parse(request.body)
        if body.is_a?(Hash)
          unknown = body.keys - op.body_keys
          violations << "#{api}: #{op.id} body has unknown keys #{unknown.inspect}" if unknown.any?
        end
      end
    rescue JSON::ParserError
      nil
    end

    def operations(api)
      (@operations ||= {})[api] ||= load(api)
    end

    def spec(api)
      (@specs ||= {})[api] ||= JSON.parse(File.read(File.expand_path("../../openapi/#{FILES.fetch(api)}", __dir__)))
    end

    def resolve(spec, node)
      while node.is_a?(Hash) && node["$ref"]
        node = node["$ref"].delete_prefix("#/").split("/").reduce(spec) { |acc, key| acc.fetch(key) }
      end
      node
    end

    private

    def load(api)
      spec = spec(api)
      spec.fetch("paths").flat_map do |template, item|
        shared = item["parameters"] || []
        item.filter_map do |verb, op|
          next unless %w[get post put patch delete].include?(verb)

          params = (shared + (op["parameters"] || [])).map { |p| resolve(spec, p) }
          Operation.new(
            id: op["operationId"], verb: verb, path_template: template,
            regex: Regexp.new("\\A#{template.split(/(\{[^}]+\})/).map { |part| part.start_with?("{") ? "[^/]+" : Regexp.escape(part) }.join}\\z"),
            query_params: params.select { |p| p["in"] == "query" }.map { |p| p["name"] },
            body_keys: body_keys(spec, op)
          )
        end
      end
    end

    def body_keys(spec, op)
      body = op["requestBody"] && resolve(spec, op["requestBody"])
      schema = body&.dig("content", "application/json", "schema")
      return unless schema

      keys = properties(spec, schema)
      keys.empty? ? nil : keys
    end

    def properties(spec, schema)
      schema = resolve(spec, schema)
      keys = (schema["properties"] || {}).keys
      %w[allOf oneOf anyOf].each do |combinator|
        Array(schema[combinator]).each { |part| keys |= properties(spec, part) }
      end
      keys
    end
  end
end

WebMock.after_request { |request, _response| OpenAPIContract.check(request) }

RSpec.configure do |config|
  config.after do |example|
    violations = OpenAPIContract.violations.dup
    OpenAPIContract.violations.clear
    next if example.metadata[:skip_contract] || violations.empty?

    raise RSpec::Expectations::ExpectationNotMetError, "OpenAPI contract violations:\n  #{violations.join("\n  ")}"
  end
end
