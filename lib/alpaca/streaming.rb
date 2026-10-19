# frozen_string_literal: true

# Real-time WebSocket streams. Opt-in because it needs the async-websocket gem
# (and msgpack for the options stream):
#
#   require "alpaca/streaming"
require_relative "../alpaca"
require_relative "streaming/transport"
require_relative "streaming/stream"
require_relative "streaming/trade_updates"
require_relative "streaming/market_data"
