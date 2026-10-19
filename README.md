# alpaca-trade-api

A complete Ruby client for [Alpaca](https://alpaca.markets): the **Trading**, **Broker** and
**Market Data** REST APIs, Server-Sent Event streams, and (optionally) real-time WebSocket streams.

- Every documented endpoint, checked against Alpaca's published OpenAPI specs.
- Lists paginate lazily and automatically. `first(10)` makes one request and `each` streams.
- Money, quantities and prices are `BigDecimal`, timestamps are `Time`, and enum values are Symbols.
- Retries are safe: 429s are always retried, timeouts only when repeating the request can't
  duplicate an order or transfer.
- Errors are structured: status, Alpaca error code and request id.

> 2.0 is a rewrite and is **not** compatible with 0.x. See [CHANGELOG.md](CHANGELOG.md).

## Installation

```ruby
gem "alpaca-trade-api", "~> 2.0"

# Only if you use WebSocket streaming:
gem "async-websocket"
gem "msgpack" # options market data stream
```

Requires Ruby 3.3+.

## Quick start

```ruby
require "alpaca"

# Reads APCA_API_KEY_ID / APCA_API_SECRET_KEY; paper trading unless paper: false.
trading = Alpaca::Trading::Client.new

trading.account.buying_power # => 0.245432e6 (BigDecimal)

order = trading.orders.create(symbol: "AAPL", qty: 1, side: :buy, type: :market, time_in_force: :day)
order.status # => :accepted

trading.positions.list.each { |p| puts "#{p.symbol} #{p.qty} #{p.unrealized_pl}" }
```

## Configuration

Credentials and options can be passed to each client or set once:

```ruby
Alpaca.configure do |c|
  c.key_id = "..."            # APCA_API_KEY_ID
  c.secret_key = "..."        # APCA_API_SECRET_KEY
  c.paper = true              # APCA_API_BASE_URL=https://api.alpaca.markets switches to live
  c.data_feed = :sip          # APCA_DATA_FEED
  c.timeout = 30
  c.max_retries = 2
  c.logger = Logger.new($stdout)  # logs method and URL, never credentials
end

Alpaca.trading      # memoized clients built from the configuration
Alpaca.market_data
Alpaca.broker
```

Every client accepts a block to customize its Faraday connection (instrumentation, adapters,
proxies):

```ruby
Alpaca::Trading::Client.new { |faraday| faraday.request :instrumentation }
```

For keep-alive connections, add `faraday-net_http_persistent` to your Gemfile and it is used automatically.

## Trading API

```ruby
trading = Alpaca::Trading::Client.new(key_id: "...", secret_key: "...", paper: false)
trading = Alpaca::Trading::Client.new(oauth_token: token)   # Alpaca Connect apps

# Account
trading.account
trading.account_configuration
trading.update_account_configuration(no_shorting: true)
trading.portfolio_history(period: "1M", timeframe: "1D").points  # => [#<data time=… equity=…>, …]
trading.activities.list(activity_types: %w[FILL DIV]).first(50)

# Orders
trading.orders.create(symbol: "AAPL", notional: 500, side: :buy, type: :market, time_in_force: :day)
trading.orders.create(symbol: "AAPL", qty: 10, side: :buy, type: :limit, limit_price: "180",
  time_in_force: :gtc, order_class: :bracket,
  take_profit: {limit_price: "200"}, stop_loss: {stop_price: "170"})
trading.orders.list(status: :all, symbols: %w[AAPL MSFT]).each { |o| ... }  # follows every page
trading.orders.find(id)
trading.orders.find_by_client_order_id("my-id")
trading.orders.replace(id, qty: 5)
trading.orders.cancel(id)
trading.orders.cancel_all          # => [Alpaca::BulkResult, …]

# Positions
trading.positions.find("AAPL")
trading.positions.close("AAPL", percentage: 50)
trading.positions.close_all(cancel_orders: true)

# Reference data
trading.assets.list(status: :active, attributes: %w[has_options])
trading.clock              # NYSE clock: phase, next_market_open, …
trading.calendar("NYSE", start: Date.today, end: Date.today + 30).days
trading.corporate_actions.announcements(ca_types: %w[dividend], since: Date.today - 30, until: Date.today)

# Watchlists, crypto funding, locates, tokenization
trading.watchlists.create(name: "tech", symbols: %w[AAPL MSFT])
trading.crypto_funding.wallets(asset: "USDC")
trading.locates.quotes(%w[GME])
trading.tokenization.requests(status: :pending)

# Account activity events (SSE)
trading.events.activities(since: Time.now - 3600).each { |event| ... }
```

`orders.create` always sends a `client_order_id`, generating one if you don't pass it. If a
submission times out, the gem raises `Alpaca::UnknownOrderStateError` with that id instead of
retrying, so you can check `orders.find_by_client_order_id` before deciding what to do.

### Options

```ruby
symbol = Alpaca::OptionSymbol.build("AAPL", expiration: Date.new(2027, 1, 15), type: :call, strike: 190)
# => "AAPL270115C00190000"
Alpaca::OptionSymbol.parse(symbol).strike # => 0.19e3

trading.option_contracts.list(underlying_symbols: %w[AAPL], type: :call,
  expiration_date_lte: Date.today + 30).first(20)

# Multi-leg (level 3): a call spread
trading.orders.create(order_class: :mleg, qty: 1, type: :limit, limit_price: "1.00", time_in_force: :day,
  legs: [
    {symbol: "AAPL270115C00190000", ratio_qty: 1, side: :buy, position_intent: :buy_to_open},
    {symbol: "AAPL270115C00210000", ratio_qty: 1, side: :sell, position_intent: :sell_to_open}
  ])

trading.positions.exercise("AAPL270115C00190000")
trading.positions.do_not_exercise("AAPL270115C00190000")
```

## Market Data API

```ruby
data = Alpaca::MarketData::Client.new(feed: :sip)   # same credentials as Trading; feed applies to stocks
data = broker.market_data                            # Broker partners: reuses the Broker credentials

# Historical data returns a lazy Series: one symbol (String) or many (Array)
bars = data.stocks.bars(%w[AAPL MSFT], timeframe: "1Day", start: Date.new(2025, 1, 1), adjustment: :all)
bars.each { |bar| puts "#{bar.symbol} #{bar.timestamp} #{bar.close}" }   # pages on demand
bars.to_h          # => {"AAPL" => [Bar, …], "MSFT" => [Bar, …]} (fetches every page)
bars.first(100)    # stops after 100 records

data.stocks.trades("AAPL", start: Time.now - 3600)
data.stocks.quotes("AAPL", start: Time.now - 60)
data.stocks.auctions(%w[AAPL], start: Date.today - 5)

# Latest values and snapshots: a String returns one record, an Array returns a Hash
data.stocks.latest_quotes("AAPL")              # => Alpaca::MarketData::Quote
data.stocks.latest_trades(%w[AAPL MSFT])       # => {"AAPL" => Trade, "MSFT" => Trade}
data.stocks.snapshots("AAPL").daily_bar.close

# Crypto (loc: defaults to "us") and options
data.crypto.bars("BTC/USD", timeframe: "1Min").first(60)
data.crypto.latest_orderbooks(%w[BTC/USD])
data.options.chain("AAPL", type: :call, strike_price_gte: 150).each { |s| puts "#{s.symbol} #{s.greeks&.delta} #{s.implied_volatility}" }
data.options.bars(%w[AAPL270115C00190000], timeframe: "1Hour")

# News, corporate actions, screeners, fixed income, logos
data.news(symbols: %w[AAPL], include_content: true).first(20)
data.corporate_actions(symbols: %w[AAPL], types: %w[cash_dividend])
data.corporate_action_events(since: Time.now - 86_400).each { |event| ... }   # SSE
data.screener.most_actives(by: :volume, top: 20)
data.screener.movers(:stocks, top: 10)
data.fixed_income.latest_prices(%w[US912797KJ59])
data.logo("AAPL")   # PNG bytes
```

Records expose readable names (`timestamp`, `open`, `close`, `vwap`, `bid_price`, `daily_bar`, …);
the raw short keys still work (`bar[:c]`). Prices and other non-integer numbers are `BigDecimal`.

## Broker API

```ruby
broker = Alpaca::Broker::Client.new(client_id: "...", client_secret: "...")   # sandbox by default
broker = Alpaca::Broker::Client.new(client_id: "...", client_assertion: -> { sign_jwt }, sandbox: false)
broker = Alpaca::Broker::Client.new(key_id: "...", secret_key: "...")         # legacy keys
```

Client-credentials tokens are fetched from `authx`, cached, shared across threads, refreshed
shortly before they expire, and refreshed once more if a request gets a 401.

```ruby
# Onboarding
account = broker.accounts.create(contact: {...}, identity: {...}, disclosures: {...}, agreements: [...])
broker.accounts.list(query: "doe").each { |a| ... }
broker.documents.upload(account.id, [{document_type: :identity_verification, mime_type: "image/jpeg",
  content_data: File.binread("id.jpg")}])  # base64-encoded for you
broker.kyc.cip(account.id)

# Funding
rel = broker.ach_relationships.create(account.id, account_owner_name: "Jane Doe", bank_account_type: :CHECKING,
  bank_account_number: "...", bank_routing_number: "...")
broker.transfers.create(account.id, transfer_type: :ach, relationship_id: rel.id, amount: "500", direction: :INCOMING)
broker.journals.create(entry_type: :JNLC, from_account: firm_id, to_account: account.id, amount: "50",
  idempotency_key: SecureRandom.uuid)
broker.journals.batch(from_account: firm_id, entries: [{to_account: a, amount: "10"}, ...])

# Trading on behalf of an account: the same resources and models as the Trading API
acct = broker.trading(account.id)
acct.orders.create(symbol: "AAPL", qty: 1, side: :buy, type: :market, time_in_force: :day)
acct.positions.list
acct.portfolio_history(period: "1W")

# Events (SSE): replay history, then stream live with automatic resume
broker.events.trades(since: Time.now - 3600).each { |event| puts "#{event.event} #{event.order.symbol}" }
broker.events.account_status.each { |event| ... }
broker.events.journals(since: Date.today, until: Date.today + 1).to_a   # bounded window

# Everything else
broker.instant_funding, broker.jit, broker.funding_wallets, broker.recipient_banks,
broker.acats, broker.rebalancing.{portfolios,subscriptions,runs}, broker.ipos, broker.fpsl,
broker.reporting, broker.oauth, broker.crypto_funding(id), broker.tokenization(id),
broker.assets.us_treasuries, broker.country_info, broker.logo("AAPL")
```

## Streaming (WebSocket)

```ruby
require "alpaca/streaming"   # needs the async-websocket gem

updates = Alpaca::Streaming::TradeUpdates.new           # same credentials as the Trading client
updates.on(:fill, :partial_fill) { |e| puts "#{e.order.symbol}: #{e.qty} @ #{e.price} (position #{e.position_qty})" }
updates.on_error { |error| warn error.message }
updates.run   # blocks; reconnects with backoff; call updates.stop from any thread to finish
```

STREAMING_```ruby
data = Alpaca::MarketData::Client.new(feed: :sip)   # same credentials as Trading; feed applies to stocks
data = broker.market_data                            # Broker partners: reuses the Broker credentials

# Historical data returns a lazy Series: one symbol (String) or many (Array)
bars = data.stocks.bars(%w[AAPL MSFT], timeframe: "1Day", start: Date.new(2025, 1, 1), adjustment: :all)
bars.each { |bar| puts "#{bar.symbol} #{bar.timestamp} #{bar.close}" }   # pages on demand
bars.to_h          # => {"AAPL" => [Bar, …], "MSFT" => [Bar, …]} (fetches every page)
bars.first(100)    # stops after 100 records

data.stocks.trades("AAPL", start: Time.now - 3600)
data.stocks.quotes("AAPL", start: Time.now - 60)
data.stocks.auctions(%w[AAPL], start: Date.today - 5)

# Latest values and snapshots: a String returns one record, an Array returns a Hash
data.stocks.latest_quotes("AAPL")              # => Alpaca::MarketData::Quote
data.stocks.latest_trades(%w[AAPL MSFT])       # => {"AAPL" => Trade, "MSFT" => Trade}
data.stocks.snapshots("AAPL").daily_bar.close

# Crypto (loc: defaults to "us") and options
data.crypto.bars("BTC/USD", timeframe: "1Min").first(60)
data.crypto.latest_orderbooks(%w[BTC/USD])
data.options.chain("AAPL", type: :call, strike_price_gte: 150).each { |s| puts "#{s.symbol} #{s.greeks&.delta} #{s.implied_volatility}" }
data.options.bars(%w[AAPL270115C00190000], timeframe: "1Hour")

# News, corporate actions, screeners, fixed income, logos
data.news(symbols: %w[AAPL], include_content: true).first(20)
data.corporate_actions(symbols: %w[AAPL], types: %w[cash_dividend])
data.corporate_action_events(since: Time.now - 86_400).each { |event| ... }   # SSE
data.screener.most_actives(by: :volume, top: 20)
data.screener.movers(:stocks, top: 10)
data.fixed_income.latest_prices(%w[US912797KJ59])
data.logo("AAPL")   # PNG bytes
```

Records expose readable names (`timestamp`, `open`, `close`, `vwap`, `bid_price`, `daily_bar`, …);
the raw short keys still work (`bar[:c]`). Prices and other non-integer numbers are `BigDecimal`.

Handlers run on the stream's reader, so keep them quick or hand work off to a queue.

## Pagination

Paginated endpoints return `Alpaca::Collection`, a lazy `Enumerable` that fetches pages as you
iterate:

```ruby
trading.orders.list(status: :all).first(10)       # one request
trading.orders.list(status: :all).each { |o| }    # every page, constant memory
trading.orders.list(status: :all).each_page { |page| page.response.rate_limit }
```

Iterating again re-runs the query from the first page.

## Errors

```ruby
begin
  trading.orders.create(symbol: "AAPL", qty: 1_000_000, side: :buy, type: :market, time_in_force: :day)
rescue Alpaca::ForbiddenError => e
  e.status      # => 403
  e.code        # => 40310000 (Alpaca's error code)
  e.api_message # => "insufficient buying power"
  e.request_id  # => "…" (X-Request-ID, useful for Alpaca support)
end
```

| Class | When |
|---|---|
| `Alpaca::BadRequestError` | 400 |
| `Alpaca::AuthenticationError` | 401 |
| `Alpaca::ForbiddenError` | 403 (e.g. insufficient buying power) |
| `Alpaca::NotFoundError` | 404 |
| `Alpaca::ConflictError` | 409 |
| `Alpaca::UnprocessableEntityError` | 422 (validation) |
| `Alpaca::RateLimitError` | 429, with `retry_after` |
| `Alpaca::ServerError` | 5xx |
| `Alpaca::ConnectionError` / `Alpaca::TimeoutError` | no response |
| `Alpaca::UnknownOrderStateError` | order submission failed without a response |

All inherit from `Alpaca::Error`. Every model keeps its HTTP response (`order.response.rate_limit.remaining`).

## Models

API objects are frozen `Alpaca::Model`s. Declared fields are typed, and any other field Alpaca
returns is still available, so new API fields work before the gem is updated:

```ruby
order.filled_avg_price   # BigDecimal
order.submitted_at       # Time
order.side               # :buy
order[:some_new_field]   # anything Alpaca adds later
order.to_h               # deep Hash with symbol keys

case order
in {status: :filled, filled_avg_price:} then puts filled_avg_price
end
```

## Development

```sh
bundle install
bundle exec rspec                    # offline; WebMock + fixtures from Alpaca's OpenAPI examples
bundle exec standardrb
bundle exec rake openapi:coverage    # documented operations vs implemented
bundle exec rake openapi:update      # refresh openapi/*.json from Alpaca, then review the diff
```

Each request in the test suite is checked against the vendored OpenAPI specs (path, verb, query
parameters and body keys), so a typo or an upstream rename makes a test fail. See
[CLAUDE.md](CLAUDE.md) for architecture and conventions.

## License

MIT
