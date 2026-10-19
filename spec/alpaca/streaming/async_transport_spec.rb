# frozen_string_literal: true

require "alpaca/streaming"
require "async/http/server"
require "async/websocket/adapters/http"
require "socket"

# End-to-end check of the async-websocket transport against a local server.
RSpec.describe Alpaca::Streaming::AsyncTransport do
  # WebMock patches Async::HTTP::Client; use the real client for this test.
  before do
    WebMock::HttpLibAdapters::AsyncHttpClientAdapter.disable!
    WebMock.allow_net_connect!
  end

  after do
    WebMock.disable_net_connect!
    WebMock::HttpLibAdapters::AsyncHttpClientAdapter.enable!
  end

  def start_server(port, received)
    ready = Thread::Queue.new
    thread = Thread.new do
      Sync do
        endpoint = Async::HTTP::Endpoint.parse("http://127.0.0.1:#{port}")
        server = Async::HTTP::Server.for(endpoint) do |request|
          Async::WebSocket::Adapters::HTTP.open(request) do |connection|
            received << JSON.parse(connection.read.buffer)
            connection.send_text(JSON.generate("stream" => "authorization", "data" => {"status" => "authorized"}))
            connection.flush
            received << JSON.parse(connection.read.buffer)
            update = {"stream" => "trade_updates", "data" => {"event" => "fill", "price" => "1.5", "order" => {"id" => "o1"}}}
            connection.send_binary(JSON.generate(update))
            connection.flush
            connection.read # wait for the client to close
          end || Protocol::HTTP::Response[404, {}, []]
        end
        task = server.run
        ready << true
        task.wait
      end
    end
    ready.pop
    thread
  end

  it "connects, authenticates, receives binary JSON and closes on stop" do
    port = TCPServer.open("127.0.0.1", 0) { |s| s.addr[1] }
    received = Thread::Queue.new
    server = start_server(port, received)

    updates = Alpaca::Streaming::TradeUpdates.new(key_id: "KEY", secret_key: "SECRET",
      url: "ws://127.0.0.1:#{port}/stream", reconnect: false)
    events = []
    updates.on_update do |event|
      events << event
      updates.stop
    end
    updates.run

    expect(events.first.price).to eq(BigDecimal("1.5"))
    expect(received.pop).to eq("action" => "auth", "key" => "KEY", "secret" => "SECRET")
    expect(received.pop).to eq("action" => "listen", "data" => {"streams" => ["trade_updates"]})
  ensure
    server&.kill
  end

  it "explains a missing async-websocket dependency" do
    allow(described_class).to receive(:require).and_raise(LoadError, "cannot load such file -- async")
    expect { described_class.load! }.to raise_error(Alpaca::MissingDependencyError, /async-websocket/)
  end
end
