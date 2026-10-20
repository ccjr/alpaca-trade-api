# frozen_string_literal: true

RSpec.describe Alpaca::HTTP::Connection do
  let(:auth) { Alpaca::HTTP::Auth::ApiKey.new("KEY", "SECRET") }
  let(:config) { Alpaca::Configuration.new.tap { |c| c.max_retries = 0 } }
  let(:connection) { described_class.new(base_url: "https://paper-api.alpaca.markets", auth: auth, config: config) }
  let(:url) { "https://paper-api.alpaca.markets/v2/orders" }

  it "sends auth headers, user agent and JSON bodies", :skip_contract do
    stub = stub_request(:post, url)
      .with(
        headers: {"APCA-API-KEY-ID" => "KEY", "APCA-API-SECRET-KEY" => "SECRET",
                  "User-Agent" => "alpaca-trade-api-ruby/#{Alpaca::VERSION}", "Content-Type" => "application/json"},
        body: json_body(qty: "1.5", limit_price: "100", at: "2024-01-02T03:04:05Z", day: "2024-01-02",
          side: "buy", legs: [{ratio_qty: 1}], extended_hours: false)
      )
      .to_return(status: 200, body: '{"id":"o1","price":1.25}', headers: {"Content-Type" => "application/json"})

    response = connection.request(:post, "/v2/orders", body: {
      qty: BigDecimal("1.5"), limit_price: BigDecimal(100), at: Time.utc(2024, 1, 2, 3, 4, 5),
      day: Date.new(2024, 1, 2), side: :buy, legs: [{ratio_qty: 1}], extended_hours: false, ignored: nil
    })

    expect(stub).to have_been_requested
    expect(response.data).to eq("id" => "o1", "price" => BigDecimal("1.25"))
    expect(response.data["price"]).to be_a(BigDecimal)
  end

  it "encodes query params" do
    stub = stub_request(:get, url).with(query: {"symbols" => "AAPL,MSFT", "after" => "2024-01-02T03:04:05.000000123Z",
                                                "nested" => "true"})
      .to_return(status: 200, body: "[]", headers: {"Content-Type" => "application/json"})

    connection.request(:get, "v2/orders", query: {symbols: %w[AAPL MSFT], status: nil, nested: true,
                                                  after: Time.utc(2024, 1, 2, 3, 4, Rational(5_000_000_123, 1_000_000_000))})
    expect(stub).to have_been_requested
  end

  it "exposes request id and rate limit headers" do
    stub_json(:get, url, [], headers: {"X-Request-ID" => "req-1", "X-RateLimit-Limit" => "200",
                                       "X-RateLimit-Remaining" => "199", "X-RateLimit-Reset" => "1700000000"})
    response = connection.request(:get, "/v2/orders")
    expect(response.request_id).to eq("req-1")
    expect(response.rate_limit).to have_attributes(limit: 200, remaining: 199, reset_at: Time.at(1_700_000_000))
  end

  it "returns nil data for empty bodies" do
    stub_request(:delete, "#{url}/1").to_return(status: 204, body: "")
    expect(connection.request(:delete, "/v2/orders/1").data).to be_nil
  end

  describe "errors" do
    {
      400 => Alpaca::BadRequestError, 401 => Alpaca::AuthenticationError, 403 => Alpaca::ForbiddenError,
      404 => Alpaca::NotFoundError, 409 => Alpaca::ConflictError, 422 => Alpaca::UnprocessableEntityError,
      429 => Alpaca::RateLimitError, 500 => Alpaca::ServerError, 503 => Alpaca::ServerError, 418 => Alpaca::APIError
    }.each do |status, klass|
      it "raises #{klass} for #{status}" do
        stub_json(:get, url, {"code" => 40_010_000, "message" => "nope"}, status: status)
        expect { connection.request(:get, "/v2/orders") }.to raise_error(klass) { |e|
          expect(e).to be_a(Alpaca::APIError)
          expect(e.status).to eq(status)
          expect(e.code).to eq(40_010_000)
          expect(e.api_message).to eq("nope")
          expect(e.message).to eq("nope (HTTP #{status}, code 40010000)")
        }
      end
    end

    it "includes the request id and handles non-JSON bodies" do
      stub_request(:get, url).to_return(status: 502, body: "<html>bad gateway</html>",
        headers: {"Content-Type" => "text/html", "X-Request-ID" => "abc"})
      expect { connection.request(:get, "/v2/orders") }.to raise_error(Alpaca::ServerError) { |e|
        expect(e.message).to eq("<html>bad gateway</html> (HTTP 502, request abc)")
        expect(e.body).to eq("<html>bad gateway</html>")
        expect(e.request_id).to eq("abc")
      }
    end

    it "handles malformed JSON error bodies" do
      stub_request(:get, url).to_return(status: 500, body: "{oops", headers: {"Content-Type" => "application/json"})
      expect { connection.request(:get, "/v2/orders") }.to raise_error(Alpaca::ServerError, "{oops (HTTP 500)")
    end

    it "handles empty error bodies" do
      stub_request(:get, url).to_return(status: 404, body: "")
      expect { connection.request(:get, "/v2/orders") }.to raise_error(Alpaca::NotFoundError, "request failed (HTTP 404)")
    end

    it "reports retry_after for rate limits" do
      stub_json(:get, url, {"message" => "slow down"}, status: 429, headers: {"X-RateLimit-Limit" => "200",
                                                                              "X-RateLimit-Reset" => (Time.now.to_i + 30).to_s})
      expect { connection.request(:get, "/v2/orders") }.to raise_error(Alpaca::RateLimitError) { |e|
        expect(e.retry_after).to be_within(2).of(30)
      }
    end

    it "falls back to Retry-After" do
      stub_json(:get, url, {}, status: 429, headers: {"Retry-After" => "3"})
      expect { connection.request(:get, "/v2/orders") }.to raise_error(Alpaca::RateLimitError) { |e|
        expect(e.retry_after).to eq(3.0)
      }
    end

    it "wraps timeouts and connection failures" do
      stub_request(:get, url).to_raise(Faraday::TimeoutError)
      expect { connection.request(:get, "/v2/orders") }.to raise_error(Alpaca::TimeoutError)

      stub_request(:get, url).to_raise(Faraday::ConnectionFailed.new("refused"))
      expect { connection.request(:get, "/v2/orders") }.to raise_error(Alpaca::ConnectionError, "refused")
    end
  end

  describe "retries" do
    let(:config) do
      Alpaca::Configuration.new.tap do |c|
        c.max_retries = 2
        c.max_retry_interval = 1
      end
    end

    before { allow_any_instance_of(Faraday::Retry::Middleware).to receive(:sleep) }

    it "retries idempotent requests on 503 and timeouts" do
      stub_request(:get, url).to_return({status: 503, body: ""}, {status: 200, body: "[]"})
      expect(connection.request(:get, "/v2/orders").status).to eq(200)

      stub_request(:delete, url).to_raise(Faraday::TimeoutError).then.to_return(status: 207, body: "[]")
      expect(connection.request(:delete, "/v2/orders").status).to eq(207)
    end

    it "retries POST on 429 because nothing was applied" do
      stub = stub_request(:post, url).to_return({status: 429, body: "", headers: {"Retry-After" => "0"}},
        {status: 200, body: "{}"})
      connection.request(:post, "/v2/orders", body: {})
      expect(stub).to have_been_requested.twice
    end

    it "does not retry POST on 503 or timeouts" do
      stub = stub_request(:post, url).to_return(status: 503, body: "")
      expect { connection.request(:post, "/v2/orders", body: {}) }.to raise_error(Alpaca::ServerError)
      expect(stub).to have_been_requested.once

      stub_request(:post, url).to_raise(Faraday::TimeoutError)
      expect { connection.request(:post, "/v2/orders", body: {}) }.to raise_error(Alpaca::TimeoutError)
      expect(stub).to have_been_requested.twice
    end

    it "retries POST with an Idempotency-Key" do
      stub = stub_request(:post, url).with(headers: {"Idempotency-Key" => "k1"})
        .to_return({status: 503, body: ""}, {status: 200, body: "{}"})
      connection.request(:post, "/v2/orders", body: {}, idempotency_key: "k1")
      expect(stub).to have_been_requested.twice
    end

    it "gives up after max_retries" do
      stub = stub_request(:get, url).to_return(status: 503, body: "")
      expect { connection.request(:get, "/v2/orders") }.to raise_error(Alpaca::ServerError)
      expect(stub).to have_been_requested.times(3)
    end

    it "does not retry when the server asks to wait longer than max_retry_interval" do
      stub = stub_request(:get, url).to_return(status: 429, body: "",
        headers: {"X-RateLimit-Reset" => (Time.now.to_i + 120).to_s})
      expect { connection.request(:get, "/v2/orders") }.to raise_error(Alpaca::RateLimitError)
      expect(stub).to have_been_requested.once
    end

    it "parses retry headers" do
      parse = ->(value) { connection.send(:seconds_until, value) }
      expect(parse.call(nil)).to be_nil
      expect(parse.call("")).to be_nil
      expect(parse.call("2.5")).to eq(2.5)
      expect(parse.call((Time.now.to_i + 10).to_s)).to be_within(2).of(10)
      expect(parse.call((Time.now + 5).httpdate)).to be_within(2).of(5)
      expect(parse.call("garbage")).to be_nil
    end

    it "does not retry a stream after yielding partial data" do
      adapter = Class.new(Faraday::Adapter) do
        class << self
          attr_accessor :calls
        end
        self.calls = 0

        def call(env)
          super
          self.class.calls += 1
          env.status = 200
          chunk = "data: {\"event_id\":\"01A\"}\n\n"
          env.request.on_data.call(chunk, chunk.bytesize, env)
          raise Faraday::TimeoutError, "late timeout"
        end
      end
      Faraday::Adapter.register_middleware alpaca_partial_timeout: adapter
      config.adapter = :alpaca_partial_timeout
      chunks = []

      expect { connection.stream("/v2/events/trades") { |chunk| chunks << chunk } }
        .to raise_error(Alpaca::TimeoutError, /late timeout/)
      expect(adapter.calls).to eq(1)
      expect(chunks.size).to eq(1)
    end
  end

  it "re-authenticates once on 401 with refreshable auth" do
    refreshable = Class.new do
      attr_reader :invalidations

      def initialize = @invalidations = 0

      def apply(headers) = headers["Authorization"] = "Bearer t#{@invalidations}"

      def refreshable? = true

      def invalidate! = @invalidations += 1
    end.new
    conn = described_class.new(base_url: "https://broker-api.sandbox.alpaca.markets", auth: refreshable, config: config)
    stub_request(:get, "https://broker-api.sandbox.alpaca.markets/v1/accounts").with(headers: {"Authorization" => "Bearer t0"})
      .to_return(status: 401, body: "")
    stub_request(:get, "https://broker-api.sandbox.alpaca.markets/v1/accounts").with(headers: {"Authorization" => "Bearer t1"})
      .to_return(status: 200, body: "[]")

    expect(conn.request(:get, "/v1/accounts").status).to eq(200)
    expect(refreshable.invalidations).to eq(1)
  end

  it "does not loop on repeated 401s" do
    stub_request(:get, url).to_return(status: 401, body: "")
    expect { connection.request(:get, "/v2/orders") }.to raise_error(Alpaca::AuthenticationError)
  end

  it "logs without leaking secrets" do
    io = StringIO.new
    config.logger = Logger.new(io)
    stub_json(:get, url, [])
    connection.request(:get, "/v2/orders")
    expect(io.string).to include("GET https://paper-api.alpaca.markets/v2/orders")
    expect(io.string).not_to include("SECRET")
  end

  it "accepts Faraday customization" do
    seen = []
    conn = described_class.new(base_url: "https://paper-api.alpaca.markets/", auth: auth, config: config) do |f|
      f.request :instrumentation, instrumenter: Class.new { define_method(:instrument) { |name, env, &b| seen << name && b.call } }.new
    end
    stub_json(:get, url, [])
    conn.request(:get, "v2/orders")
    expect(seen).to eq(["request.faraday"])
    expect(conn.inspect).to include("paper-api")
  end

  it "honors a Faraday adapter selected in the customization block" do
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.get("/v2/orders") { [200, {"Content-Type" => "application/json"}, "[]"] }
    end
    conn = described_class.new(base_url: "https://example.test", auth: auth, config: config) do |f|
      f.adapter :test, stubs
    end

    expect(conn.request(:get, "/v2/orders").data).to eq([])
    stubs.verify_stubbed_calls
  end
end
