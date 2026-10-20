# frozen_string_literal: true

RSpec.describe Alpaca::HTTP::Auth do
  describe Alpaca::HTTP::Auth::ApiKey do
    it "sets APCA headers and stream credentials" do
      auth = described_class.new("KEY", "SECRET")
      headers = {}
      auth.apply(headers)
      expect(headers).to eq("APCA-API-KEY-ID" => "KEY", "APCA-API-SECRET-KEY" => "SECRET")
      expect(auth.stream_credentials).to eq(key: "KEY", secret: "SECRET")
      expect(auth.refreshable?).to be(false)
      expect(auth.invalidate!).to be_nil
      expect(auth.inspect).not_to include("SECRET")
    end

    it "requires both values" do
      expect { described_class.new(nil, "s") }.to raise_error(Alpaca::ConfigurationError)
      expect { described_class.new("k", "") }.to raise_error(Alpaca::ConfigurationError)
    end
  end

  describe Alpaca::HTTP::Auth::Bearer do
    it "sets a bearer token" do
      auth = described_class.new("tok")
      headers = {}
      auth.apply(headers)
      expect(headers).to eq("Authorization" => "Bearer tok")
      expect(auth.stream_credentials).to eq(key: "oauth", secret: "tok")
      expect(auth.refreshable?).to be(false)
      expect(auth.invalidate!).to be_nil
      expect(auth.inspect).not_to include("tok")
      expect { described_class.new("") }.to raise_error(Alpaca::ConfigurationError)
    end
  end

  describe Alpaca::HTTP::Auth::Basic do
    it "sets HTTP basic credentials" do
      auth = described_class.new("user", "pass")
      headers = {}
      auth.apply(headers)
      expect(headers).to eq("Authorization" => "Basic dXNlcjpwYXNz")
      expect(auth.stream_credentials).to eq(key: "user", secret: "pass")
      expect(auth.refreshable?).to be(false)
      expect(auth.invalidate!).to be_nil
      expect(auth.inspect).not_to include("pass")
      expect { described_class.new("user", nil) }.to raise_error(Alpaca::ConfigurationError)
    end
  end

  describe Alpaca::HTTP::Auth::ClientCredentials do
    let(:token_url) { "https://authx.sandbox.alpaca.markets/v1/oauth2/token" }

    it "fetches, caches and refreshes tokens" do
      stub = stub_request(:post, token_url)
        .with(body: {"grant_type" => "client_credentials", "client_id" => "cid", "client_secret" => "cs"})
        .to_return(
          {status: 200, body: '{"access_token":"t1","expires_in":899}', headers: {"Content-Type" => "application/json"}},
          {status: 200, body: '{"access_token":"t2","expires_in":899}', headers: {"Content-Type" => "application/json"}}
        )
      auth = described_class.new(client_id: "cid", client_secret: "cs", token_url: token_url)

      headers = {}
      auth.apply(headers)
      auth.apply(headers)
      expect(headers["Authorization"]).to eq("Bearer t1")
      expect(stub).to have_been_requested.once

      auth.invalidate!
      expect(auth.stream_credentials).to eq(key: "access_token", secret: "t2")
      expect(stub).to have_been_requested.twice
      expect(auth.refreshable?).to be(true)
      expect(auth.inspect).to include("cid")
    end

    it "refreshes shortly before expiry" do
      stub_request(:post, token_url).to_return(
        {status: 200, body: '{"access_token":"t1","expires_in":30}', headers: {"Content-Type" => "application/json"}},
        {status: 200, body: '{"access_token":"t2","expires_in":900}', headers: {"Content-Type" => "application/json"}}
      )
      auth = described_class.new(client_id: "cid", client_secret: "cs", token_url: token_url)
      expect(auth.token).to eq("t1")
      expect(auth.token).to eq("t2")
    end

    it "supports private_key_jwt assertions" do
      stub = stub_request(:post, token_url)
        .with(body: {"grant_type" => "client_credentials", "client_id" => "cid",
                     "client_assertion_type" => described_class::ASSERTION_TYPE, "client_assertion" => "signed.jwt"})
        .to_return(status: 200, body: '{"access_token":"t","expires_in":900}', headers: {"Content-Type" => "application/json"})
      described_class.new(client_id: "cid", client_assertion: -> { "signed.jwt" }, token_url: token_url).token
      expect(stub).to have_been_requested
    end

    it "raises API errors from the token endpoint" do
      stub_request(:post, token_url).to_return(status: 401, body: '{"message":"invalid_client"}',
        headers: {"Content-Type" => "application/json"})
      auth = described_class.new(client_id: "cid", client_secret: "bad", token_url: token_url)
      expect { auth.token }.to raise_error(Alpaca::AuthenticationError, /invalid_client/)
    end

    it "wraps connection failures" do
      stub_request(:post, token_url).to_raise(Faraday::ConnectionFailed.new("down"))
      auth = described_class.new(client_id: "cid", client_secret: "cs", token_url: token_url)
      expect { auth.token }.to raise_error(Alpaca::ConnectionError, /down/)
    end

    it "applies client HTTP configuration to token requests" do
      config = Alpaca::Configuration.new.tap do |c|
        c.timeout = 1
        c.open_timeout = 2
        c.max_retries = 0
        c.user_agent = "configured-agent"
      end
      seen = nil
      stubs = Faraday::Adapter::Test::Stubs.new do |stub|
        stub.post(token_url) do |env|
          seen = env
          [200, {"Content-Type" => "application/json"}, '{"access_token":"t","expires_in":900}']
        end
      end
      auth = described_class.new(client_id: "cid", client_secret: "cs", token_url: token_url, config: config) do |f|
        f.adapter :test, stubs
      end

      expect(auth.token).to eq("t")
      expect(seen.request_headers["User-Agent"]).to eq("configured-agent")
      expect(seen.request.timeout).to eq(1)
      expect(seen.request.open_timeout).to eq(2)
      stubs.verify_stubbed_calls
    end

    it "validates configuration" do
      expect { described_class.new(client_id: nil, client_secret: "x", token_url: token_url) }
        .to raise_error(Alpaca::ConfigurationError)
      expect { described_class.new(client_id: "cid", token_url: token_url) }.to raise_error(Alpaca::ConfigurationError)
    end
  end
end
