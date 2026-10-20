# frozen_string_literal: true

module Alpaca
  # Base class for API resources (groups of endpoints).
  #
  # `operation` records which OpenAPI operation the next method implements:
  #
  #   operation trading: "postOrder", broker: "createOrderForAccount"
  #   def create(...)
  #
  # A resource may be scoped: Trading resources use "/v2" against the Trading
  # API and "/v1/trading/accounts/{id}" when acting for a Broker account.
  class Resource
    class << self
      def operation(**ids)
        @pending_operations = ids
      end

      private

      def method_added(name)
        super
        ids = @pending_operations
        return unless ids

        @pending_operations = nil
        ids.each { |api, id| Array(id).each { |op| OperationRegistry.register(api, op, "#{self.name}##{name}") } }
      end
    end

    attr_reader :client, :scope

    def initialize(client, scope: nil, **options)
      @client = client
      @scope = scope
      @options = options
    end

    def inspect = "#<#{self.class.name}#{" #{scope}" if scope}>"

    private

    def connection = client.connection

    def broker? = scope.to_s.start_with?("/v1/trading/accounts/")

    # Builds "/a/b/<escaped>" from a base path and dynamic segments.
    def path(base, *segments)
      segments.compact.reduce(base) { |acc, segment| "#{acc}/#{HTTP::Params.segment(segment)}" }
    end

    def scoped(relative, *segments) = path("#{scope}/#{relative}", *segments)

    def api_request(method, path, model: nil, query: nil, body: nil, headers: nil, idempotency_key: nil)
      response = connection.request(
        method, path, query: query, body: body, headers: headers, idempotency_key: idempotency_key
      )
      model ? model.build(response.data, response: response) : response.data
    end

    def http_get(path, **) = api_request(:get, path, **)

    def http_post(path, **) = api_request(:post, path, **)

    def http_put(path, **) = api_request(:put, path, **)

    def http_patch(path, **) = api_request(:patch, path, **)

    def http_delete(path, **) = api_request(:delete, path, **)

    # Raw body for binary endpoints (logos, document downloads).
    def download(path, query: nil)
      connection.request(:get, path, query: query, headers: {"Accept" => "*/*"}).body
    end

    # Pages that use `page_token` in the request and return the next token in
    # the body (`next_page_token` by default).
    def paginate(path, model:, query:, items_key:, token_param: "page_token", token_key: "next_page_token")
      Collection.new do |cursor|
        params = cursor ? query.merge(token_param => cursor) : query
        response = connection.request(:get, path, query: params)
        data = response.data || {}
        items = model.build(items_key ? data[items_key] : data, response: response) || []
        token = data.is_a?(Hash) ? data[token_key] : nil
        Collection::Page.new(items: items, next_cursor: (token.nil? || token == "") ? nil : token, response: response)
      end
    end

    # Pages where the next request passes the last item's id as the cursor and
    # a short page means there is nothing more (account activities).
    def paginate_by_last_id(path, model:, query:, size_param: "page_size", size: 100, token_param: "page_token")
      query = {size_param => size}.merge(query.transform_keys(&:to_s))
      page_size = query[size_param].to_i
      Collection.new do |cursor|
        params = cursor ? query.merge(token_param => cursor) : query
        response = connection.request(:get, path, query: params)
        items = model.build(response.data, response: response) || []
        next_cursor = (items.size < page_size) ? nil : items.last.id
        Collection::Page.new(items: items, next_cursor: next_cursor, response: response)
      end
    end

    # Pages addressed by an integer offset. The initial offset supplied by the
    # caller is preserved and subsequent requests advance by the actual number
    # of records returned.
    def paginate_by_offset(path, model:, query:, size: 100)
      query = {"limit" => size}.merge(query.transform_keys(&:to_s))
      page_size = query["limit"].to_i
      initial_offset = query.fetch("offset", 0).to_i
      raise ArgumentError, "limit must be positive" unless page_size.positive?

      Collection.new do |cursor|
        params = cursor.nil? ? query : query.merge("offset" => cursor)
        response = connection.request(:get, path, query: params)
        items = model.build(response.data, response: response) || []
        current_offset = cursor.nil? ? initial_offset : cursor
        next_cursor = (items.size < page_size) ? nil : current_offset + items.size
        Collection::Page.new(items: items, next_cursor: next_cursor, response: response)
      end
    end

    def require_broker!(method)
      raise Error, "#{method} is only available through Alpaca::Broker::Client#trading(account_id)" unless broker?
    end
  end
end
