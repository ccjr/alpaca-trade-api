# frozen_string_literal: true

PAPER = "https://paper-api.alpaca.markets"
BROKER_SANDBOX = "https://broker-api.sandbox.alpaca.markets"
DATA = "https://data.alpaca.markets"

module ApiHelpers
  def trading_client(**options)
    Alpaca::Trading::Client.new(key_id: "KEY", secret_key: "SECRET", **options)
  end

  # Stubs a JSON response. `body` may be any JSON-serializable value.
  def stub_json(method, url, body = {}, status: 200, headers: {}, query: nil, request_body: nil)
    stub = stub_request(method, url)
    with = {}
    with[:query] = query if query
    with[:body] = request_body if request_body
    stub = stub.with(**with) unless with.empty?
    stub.to_return(
      status: status,
      body: body.nil? ? "" : JSON.generate(body),
      headers: {"Content-Type" => "application/json"}.merge(headers)
    )
  end

  # Matches a JSON request body, ignoring key order.
  def json_body(expected)
    ->(body) { JSON.parse(body) == JSON.parse(JSON.generate(expected)) }
  end

  def fixture(name)
    JSON.parse(File.read(File.join(__dir__, "..", "fixtures", "#{name}.json")))
  end

  # A response example published in Alpaca's OpenAPI spec, so fixtures match
  # what the docs promise. `name` picks one of several named examples.
  def openapi_example(api, path, verb = "get", name = nil)
    spec = OpenAPIContract.spec(api)
    responses = spec.dig("paths", path, verb, "responses")
    raise ArgumentError, "no operation #{verb.upcase} #{path}" unless responses

    _, response = responses.find { |code, _| code.start_with?("2") }
    content = OpenAPIContract.resolve(spec, response).dig("content", "application/json") || {}
    example = content["example"]
    if example.nil? && content["examples"]
      examples = content["examples"]
      chosen = name ? examples.fetch(name) : examples.values.first
      example = OpenAPIContract.resolve(spec, chosen)["value"]
    end
    raise ArgumentError, "no example for #{verb.upcase} #{path}" if example.nil?

    example
  end

  def openapi_named_example(api, name)
    spec = OpenAPIContract.spec(api)
    spec.dig("components", "examples", name, "value") || raise(ArgumentError, "no example #{name}")
  end
end
