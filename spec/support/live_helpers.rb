# frozen_string_literal: true

# Helpers for spec/live, which runs against Alpaca's paper (Trading), sandbox
# (Broker) and free-tier Market Data environments. Clients are pinned to paper
# and sandbox so a live key in the environment can never place real orders.
module LiveHelpers
  def skip_without(*names)
    missing = names.select { |name| ENV[name].to_s.empty? }
    skip "set #{missing.join(", ")} to run" if missing.any?
  end

  def skip_without_trading_keys = skip_without("APCA_API_KEY_ID", "APCA_API_SECRET_KEY")

  def skip_without_broker_credentials
    return if ENV.values_at("APCA_BROKER_CLIENT_ID", "APCA_BROKER_CLIENT_SECRET").none? { |v| v.to_s.empty? }
    return if ENV.values_at("APCA_BROKER_API_KEY_ID", "APCA_BROKER_API_SECRET_KEY").none? { |v| v.to_s.empty? }

    skip "set APCA_BROKER_CLIENT_ID/SECRET (or APCA_BROKER_API_KEY_ID/SECRET_KEY) to run"
  end

  def paper_trading = Alpaca::Trading::Client.new(paper: true)

  def sandbox_broker = Alpaca::Broker::Client.new(sandbox: true)

  # Free plans only include the IEX feed.
  def market_data = Alpaca::MarketData::Client.new(feed: ENV.fetch("APCA_DATA_FEED", "iex").to_sym)

  # Runs a WebSocket stream on a thread until it stops itself or `timeout` passes.
  # Returns true when it stopped in time; errors that end the stream are re-raised.
  def run_stream(stream, timeout: 30)
    thread = Thread.new do
      Thread.current.report_on_exception = false
      stream.run
    end
    !thread.join(timeout).nil?
  ensure
    stream.stop
    thread&.join(5) || thread&.kill
  end

  # Unique, recognizable names for objects the live specs create (and delete).
  def live_name(prefix) = "#{prefix}-#{SecureRandom.hex(4)}"
end
