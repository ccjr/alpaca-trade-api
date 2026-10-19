# frozen_string_literal: true

require "json"

# Drafts an Alpaca::Model class from an OpenAPI schema. The output is a starting
# point to review and edit by hand, not generated code to commit blindly.
#
#   rake "openapi:model[broker,ACHRelationship,AchRelationship]"
class ModelGenerator
  DECIMAL_NAMES = /(amount|price|qty|quantity|value|fees?|balance|cost|equity|cash|margin|power|percent|pct|
    commission|notional|interest|bps|apr|yield|rate|limit_amount|basis|pl|plpc|exposure|weight)\z/x

  def initialize(api, dir: File.expand_path("../openapi", __dir__))
    @spec = JSON.parse(File.read(File.join(dir, "#{api.to_s.tr("_", "-")}-api.json")))
  end

  def generate(schema_name, class_name = schema_name)
    props = properties(schema(schema_name))
    lines = props.map { |name, prop| "    attribute :#{name}, #{type_for(name, prop)}" }
    "  class #{class_name} < Model\n#{lines.join("\n")}\n  end\n"
  end

  private

  def schema(name) = @spec.dig("components", "schemas", name) || raise(ArgumentError, "unknown schema #{name}")

  def resolve(node)
    node = node["$ref"].delete_prefix("#/").split("/").reduce(@spec) { |acc, key| acc.fetch(key) } while node.is_a?(Hash) && node["$ref"]
    node
  end

  def properties(node)
    node = resolve(node)
    props = (node["properties"] || {}).dup
    %w[allOf oneOf anyOf].each { |key| Array(node[key]).each { |part| props.merge!(properties(part)) } }
    props
  end

  def type_for(name, prop)
    ref = prop["$ref"] || Array(prop["allOf"]).find { |p| p["$ref"] }&.fetch("$ref")
    prop = resolve(prop)
    type = Array(prop["type"]).reject { |t| t == "null" }.first || (prop["allOf"] && resolve(prop["allOf"].first)["type"])
    format = prop["format"]
    case type
    when "array"
      item = resolve(prop["items"] || {})
      item_type = Array(item["type"]).first
      return "[:string]" if item_type == "string"
      return "[:decimal]" if item_type == "number"
      return "[:integer]" if item_type == "integer"

      "[:raw]"
    when "integer" then ":integer"
    when "number" then ":decimal"
    when "boolean" then ":boolean"
    when "string"
      return ":time" if format == "date-time"
      return ":date" if format == "date"
      return ":decimal" if format == "decimal" || name.match?(DECIMAL_NAMES)
      return ":symbol" if prop["enum"]

      ":string"
    else
      ref ? ":raw # #{ref.split("/").last}" : ":raw"
    end
  end
end
