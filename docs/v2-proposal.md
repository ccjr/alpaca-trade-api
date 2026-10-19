# alpaca-trade-api 2.0 — Design Proposal

Status: **implemented on `v2`** · 2026-10-19 (decisions in §10, deviations in §11)

## 1. Goals

1. **Cover every documented endpoint** in the Trading, Broker and Market Data APIs, plus the
   real-time WebSocket and SSE streams.
2. **Make the common path short.** Placing an order, pulling a year of bars, or streaming
   quotes should take one or two lines, with pagination, auth refresh and retries handled for you.
3. **Stay current without heroic effort.** Coverage is measured against Alpaca's published
   OpenAPI specs, so a new endpoint shows up as a failing coverage check instead of a GitHub issue.
4. **Be fast and safe in production.** Reuse persistent connections, keep clients thread-safe,
   retry only when it's safe to, and return structured errors.

Non-goals: backwards compatibility with 0.x, or reproducing Alpaca's server-side validation on
the client. Alpaca changes its rules often, and a stale client-side check is worse than none.

## 2. Why 0.x can't be extended

- It covers about 20 of ~265 REST endpoints and no streaming.
- It opens a new Faraday connection for every request, so there's no keep-alive.
- Errors are raised from ad-hoc per-method status checks. The only details kept are a class
  name and a message. The Alpaca error `code`, the request id and rate-limit headers are dropped.
- Models are hand-copied attribute lists, so new fields Alpaca adds are silently dropped.
  Numeric strings stay strings in some places and become BigDecimal in others.
- There is no pagination support. Trading and Market Data share one class hierarchy, and
  `Market::Client` inherits from the Trading client.
- It depends on Faraday `< 2.0` and targets Ruby 2.5 on Travis. 4 specs currently fail
  (ActiveSupport's `present?` is used without depending on ActiveSupport).

## 3. Scope inventory (from the OpenAPI specs, Oct 2026)

| API | Endpoints | Groups |
|---|---|---|
| Trading (`/v1`, `/v2`, `/v3`) | 58 | Orders 7, Positions 6 (incl. option exercise/DNE), Watchlists 11, Assets + option contracts 4, Account, Configurations 2, Activities 2, Portfolio history, Clock 2, Calendar 2, Corporate actions 2, Crypto wallets 9, Locates 4, Tokenization 4, Events (SSE) 1 |
| Market Data | 42 | Stocks 18, Options 8, Crypto 8, Corporate actions 2, Fixed income 2, Screener 2, News, Logos |
| Broker | 163 | Trading-on-behalf 17, Funding 16, Rebalancing 13, Funding wallets 11, Accounts 11, Events (SSE) 11, Crypto funding 10, Instant funding 10, Tokenization 7, Assets 7, Watchlists 7, ACATS 6, Journals 6, KYC 4, Documents 4, Calendar/Clock 4, FPSL 3, OAuth 3, Reporting 3, IPO 2, Corporate actions 2, misc 6 |
| Streaming (not in OpenAPI) | — | `trade_updates`; market data stocks (`v2/{iex,sip,delayed_sip,…}`), crypto (`v1beta3/crypto/{loc}`), options (`v1beta1/{indicative,opra}`, msgpack-only), news (`v1beta1/news`), test stream |

## 4. Package layout

```
lib/
  alpaca.rb                       # require "alpaca" → REST clients only
  alpaca/
    version.rb
    configuration.rb              # defaults + env var loading
    errors.rb
    http/
      connection.rb               # one persistent Faraday 2 connection per client
      auth.rb                     # ApiKey, Bearer (Connect), BrokerToken (authx, auto-refresh), Basic
      retry_policy.rb
      response.rb                 # status, headers, request_id, rate_limit
    pagination/
      token_cursor.rb             # page_token / next_page_token
      time_cursor.rb              # /v2/orders after/until
      symbol_series.rb            # market data {symbol => [...]} merging across pages
    model.rb                      # typed attributes + passthrough of unknown fields
    models/                       # Order, Position, Account, Asset, OptionContract, Bar, Quote…
    resource.rb                   # base class: path prefix, verbs, operation registry
    trading/client.rb + trading/resources/*.rb
    market_data/client.rb + market_data/resources/*.rb
    broker/client.rb + broker/resources/*.rb
    options/symbol.rb             # OCC symbol build/parse
    streaming.rb                  # require "alpaca/streaming" → opt-in deps
    streaming/
      websocket.rb                # connect, auth, heartbeat, reconnect, resubscribe
      trade_updates.rb
      market_data.rb              # stocks / crypto / options / news
      sse.rb                      # Server-Sent Events over Net::HTTP (no extra deps)
openapi/                          # vendored copies of the three specs (dated)
```

Top-level namespace becomes `Alpaca::` (it was `Alpaca::Trade::Api::`). The gem keeps the
`alpaca-trade-api` name on RubyGems; the require path becomes `require "alpaca"`.

## 5. Public API by example

### Clients

```ruby
require "alpaca"

trading = Alpaca::Trading::Client.new                     # APCA_API_KEY_ID / APCA_API_SECRET_KEY, paper by default
trading = Alpaca::Trading::Client.new(key_id:, secret_key:, paper: false)
trading = Alpaca::Trading::Client.new(oauth_token: token) # Alpaca Connect

data    = Alpaca::MarketData::Client.new(feed: :sip)      # default feed for stock calls
broker  = Alpaca::Broker::Client.new(client_id:, client_secret:, sandbox: true)

# Shorthands
Alpaca.trading / Alpaca.market_data / Alpaca.broker       # memoized clients built from env/config
```

Clients are immutable and thread-safe. Each one holds a single persistent connection.
`Alpaca.configure { |c| c.logger = Rails.logger; c.timeout = 10; c.max_retries = 3 }` sets
defaults. Any client can also take a `faraday:` block to add middleware (instrumentation, VCR, etc.).

### Trading

```ruby
trading.account                                           # => Alpaca::Account
trading.account_configuration / trading.update_account_configuration(pdt_check: "entry")
trading.activities.list(activity_types: %w[FILL DIV], after: Time.now - 7 * 86_400)   # lazy, auto-paginated
trading.portfolio_history(period: "1M", timeframe: "1D")

order = trading.orders.create(symbol: "AAPL", qty: 1, side: :buy, type: :market, time_in_force: :day)
trading.orders.create(symbol: "AAPL", notional: 500, side: :buy, type: :market, time_in_force: :day)
trading.orders.create(symbol: "AAPL", qty: 10, side: :buy, type: :limit, limit_price: 180,
                      time_in_force: :gtc, order_class: :bracket,
                      take_profit: { limit_price: 200 }, stop_loss: { stop_price: 170 })
trading.orders.list(status: :all, symbols: %w[AAPL MSFT]).each { |o| ... } # walks every page
trading.orders.find(order.id) / trading.orders.find_by_client_order_id("my-id")
trading.orders.replace(order.id, qty: 2)
trading.orders.cancel(order.id) / trading.orders.cancel_all

trading.positions.list / trading.positions.find("AAPL")
trading.positions.close("AAPL", percentage: 50) / trading.positions.close_all(cancel_orders: true)

trading.assets.list(status: :active, attributes: %w[options_enabled])
trading.watchlists.create(name: "tech", symbols: %w[AAPL MSFT]).add("NVDA")
trading.clock(markets: %w[NYSE])                          # v3
trading.calendar(:NYSE, start: Date.today, end: Date.today + 30)
trading.corporate_actions.announcements(ca_types: %w[dividend], since:, until:)
trading.crypto_wallets.list / .transfers / .whitelists …
trading.locates.create(...) / trading.tokenization.mint(..., idempotency_key: SecureRandom.uuid)
```

### Options

```ruby
sym = Alpaca::Options::Symbol.build("AAPL", expiration: Date.new(2027, 1, 15), type: :call, strike: 190)
# => "AAPL270115C00190000";  Alpaca::Options::Symbol.parse(sym) => #<data root="AAPL" expiration=… type=:call strike=190.0>

trading.options.contracts(underlying_symbols: %w[AAPL], expiration_date_lte: Date.today + 30, type: :call)
trading.options.contract("AAPL270115C00190000")
trading.positions.exercise("AAPL270115C00190000") / trading.positions.do_not_exercise(...)

trading.orders.create(order_class: :mleg, qty: 1, type: :limit, limit_price: 1.00, time_in_force: :day,
  legs: [
    { symbol: "AAPL270115C00190000", ratio_qty: 1, side: :buy,  position_intent: :buy_to_open },
    { symbol: "AAPL270115C00210000", ratio_qty: 1, side: :sell, position_intent: :sell_to_open },
  ])

data.options.chain("AAPL", type: :put, strike_price_gte: 150)   # snapshots incl. greeks/IV
data.options.bars(%w[AAPL270115C00190000], timeframe: "1Hour")
```

### Market data

Every historical endpoint accepts one symbol or many, follows `next_page_token` automatically,
and returns a lazy `Alpaca::Series`:

```ruby
bars = data.stocks.bars(%w[AAPL MSFT], timeframe: "1Day", start: Date.new(2025, 1, 1), adjustment: :all)
bars.each { |bar| bar.symbol; bar.close }  # streams pages; constant memory
bars.to_h                                  # => { "AAPL" => [Bar, …], "MSFT" => [Bar, …] } (fetches all)
bars.each_page { |page| ... }              # raw page access when you need it
bars.limit(10_000)                         # stop after N records total

data.stocks.latest_quotes(%w[AAPL MSFT])   # => { "AAPL" => Quote, … }
data.stocks.snapshots(%w[AAPL])
data.stocks.trades("AAPL", start: Time.now - 3600)
data.crypto.bars("BTC/USD", timeframe: "1Min")            # loc defaults to :us
data.crypto.latest_orderbooks(%w[BTC/USD])
data.news(symbols: %w[AAPL], include_content: true)
data.screener.most_actives(by: :volume, top: 20) / data.screener.movers(:stocks)
data.corporate_actions(symbols: %w[AAPL], types: %w[cash_dividend])
data.fixed_income.latest_prices(isins: [...])
data.logo("AAPL")                                         # => binary String (image)
```

The single-symbol variants (`/v2/stocks/{symbol}/bars`) are implemented too, but the gem routes
a single symbol through the multi-symbol endpoint so callers get one return shape.

### Broker

```ruby
acct = broker.accounts.create(contact: {...}, identity: {...}, disclosures: {...}, agreements: [...])
broker.accounts.list(query: "doe", status: :active).each { ... }
broker.accounts.documents(acct.id).upload(document_type: :identity_verification, content: File.binread(path), mime_type: "image/jpeg")
broker.funding.ach_relationships(acct.id).create(...)
broker.funding.transfers(acct.id).create(transfer_type: :ach, amount: 1000, direction: :incoming, relationship_id:)
broker.journals.create(from_account:, to_account:, entry_type: :JNLC, amount: 50)
broker.journals.batch(entries: [...])

# Trading on behalf of an account reuses the Trading resources and models; only the path prefix changes
broker.trading(acct.id).orders.create(symbol: "AAPL", qty: 1, side: :buy, type: :market, time_in_force: :day)
broker.trading(acct.id).positions.list
broker.trading(acct.id).portfolio_history(period: "1W")

broker.rebalancing.portfolios.create(...) / broker.acats.request(acct.id, ...) / broker.ipos.list …
```

### Streaming (`require "alpaca/streaming"`)

```ruby
stream = Alpaca::Streaming::MarketData.new(feed: :sip)            # or .crypto, .options(feed: :opra), .news, .test
stream.on_trade("AAPL", "MSFT") { |t| puts "#{t.symbol} #{t.price}" }
stream.on_quote("AAPL")         { |q| ... }
stream.on_bar("*")              { |b| ... }
stream.on_error                 { |e| logger.warn(e) }
stream.run                                                       # blocks; reconnects with backoff and resubscribes

updates = Alpaca::Streaming::TradeUpdates.new(paper: true)
updates.on(:fill, :partial_fill) { |event| event.order; event.price; event.position_qty }
updates.run

broker.events.trades(since: Time.now - 3600).each { |event| ... }     # SSE: replay history, then live
```

Subscriptions can be changed while a stream is running (`stream.subscribe(quotes: %w[NVDA])`),
from any thread.

## 6. Core design decisions

### 6.1 HTTP

- **Faraday 2.x** with one persistent connection per client (`net_http_persistent` adapter if
  it's installed, otherwise `net_http`), JSON request/response middleware, and configurable
  `timeout`/`open_timeout`.
- `User-Agent: alpaca-trade-api-ruby/2.x`. Secrets are redacted from logs.
- Every response object exposes `status`, `headers`, `request_id` (`X-Request-ID`) and
  `rate_limit` (`limit`, `remaining`, `reset_at`). Models keep a reference so you can call
  `order.response.rate_limit.remaining`.

### 6.2 Retries (safe by default)

| Situation | GET / DELETE / PUT | POST / PATCH |
|---|---|---|
| 429 | retry, waiting until `X-RateLimit-Reset`/`Retry-After`, else exponential backoff + jitter | retry (the request was rejected, so nothing was applied) |
| 502/503/504, connection reset, timeout | retry with backoff | retry **only** if an `Idempotency-Key` was sent; otherwise raise |

`max_retries` defaults to 2. Order submission is never auto-retried after an ambiguous failure.
Instead, the error includes the `client_order_id` so the caller can look the order up.
`orders.create` generates a `client_order_id` when the caller doesn't pass one.

### 6.3 Errors

```
Alpaca::Error
├── Alpaca::ConfigurationError
├── Alpaca::ConnectionError        (wraps Faraday::ConnectionFailed / TimeoutError)
└── Alpaca::APIError               #status #code #message #request_id #body #response
    ├── BadRequestError        400
    ├── AuthenticationError    401
    ├── ForbiddenError         403   (e.g. code 40310000 insufficient buying power)
    ├── NotFoundError          404
    ├── UnprocessableError     422
    ├── RateLimitError         429   #retry_after
    └── ServerError            5xx
```

One central mapper replaces every per-method `raise X if status == N`. Alpaca's numeric `code`
is kept so callers can branch on it.

### 6.4 Models

```ruby
class Alpaca::Order < Alpaca::Model
  attribute :id,              :string
  attribute :qty,             :decimal     # "1.5" → BigDecimal
  attribute :filled_avg_price,:decimal
  attribute :submitted_at,    :time
  attribute :side,            :symbol      # "buy" → :buy
  attribute :legs,            [Alpaca::Order]
end
```

- Declared attributes are coerced: `BigDecimal` for every non-integer number (money, quantities, market data), `Time` for timestamps,
  `Date` for dates, symbols for enums.
- **Undeclared fields are kept**. `order[:some_new_field]`, `order.to_h` and `respond_to_missing?`
  give access to them, so a field Alpaca adds is usable before the gem catches up.
- Models are frozen, support `==`, and pattern matching through `deconstruct_keys`.
- Market data tick types (Bar, Trade, Quote, OrderbookLevel, …) are `Data.define` structs with
  readable names (`t/o/h/l/c/v/n/vw` → `timestamp/open/high/low/close/volume/trade_count/vwap`).
  Prices are `BigDecimal` like everywhere else: responses are parsed with
  `JSON.parse(body, decimal_class: BigDecimal)`, so JSON numbers become exact decimals directly,
  with no lossy Float round trip.
- The attribute declarations are seeded by a generator script that reads the OpenAPI schemas
  (`rake openapi:models[Order]` prints a starting class). The output is reviewed by hand and
  committed. The generator is not part of the build.

### 6.5 Request params

- Keyword args are named after Alpaca's JSON fields. `until:` is accepted (as `**opts` with
  `opts[:until]`) because Ruby callers can pass reserved words as keyword arguments.
- `Time`/`DateTime` values are sent as RFC 3339, `Date` as ISO 8601, `BigDecimal`/`Numeric` as
  strings where Alpaca expects strings, and arrays as comma-joined values for list-type query params.
- Required params are required keywords. No other validation happens client-side.

### 6.6 Pagination

The `Alpaca::Series`/`Alpaca::Collection` objects are `Enumerable` and lazy. They fetch the next
page only when iteration reaches it. Three cursor strategies cover the API:

1. `page_token` → `next_page_token` (market data, most broker lists, option contracts).
2. Last item id as `page_token` (account activities).
3. Time window (`/v2/orders`: advance `after`/`until` using the last `submitted_at`).

Endpoints that return a bare array without paging return a plain `Array`.

### 6.7 Resource definitions and coverage tracking

Each resource method states which OpenAPI operation it implements:

```ruby
class Alpaca::Trading::Orders < Alpaca::Resource
  operation "postOrder"
  def create(symbol: nil, side: nil, type:, time_in_force:, client_order_id: SecureRandom.uuid, **params)
    post("orders", body: { symbol:, side:, type:, time_in_force:, client_order_id:, **params }, model: Order)
  end
end
```

`rake openapi:coverage` loads the vendored specs, compares them with the operation registry, and
prints what's implemented, what's missing, and what's intentionally skipped (with a reason, e.g.
`LegacyClock: superseded by v3`). CI fails if an operation is neither implemented nor skipped.
`rake openapi:update` re-downloads the specs and shows the diff, which makes it easy to keep up
with Alpaca.

### 6.8 Streaming

- **WebSocket transport:** `async-websocket` (fiber-based, supports permessage-deflate,
  maintained). `run` wraps it in `Sync { }` so callers don't need to know about Async. It is a
  *soft* dependency: the gemspec doesn't add it, and `require "alpaca/streaming"` raises a clear
  message if it's missing. The same applies to `msgpack`, which only the options stream needs.
- Handles auth (key, `access_token`, or `oauth`), the connection-limit error (406) as a specific
  exception, ping/pong, reconnect with exponential backoff, and automatic resubscribe.
- **SSE** (Broker events, trading activities, corporate-action events): a small parser over
  `Net::HTTP` streaming. It needs no extra dependency and supports `since`/`until`/`since_id`
  replay plus automatic resume from the last event id.

### 6.9 Broker auth

`BrokerToken` exchanges `client_id`/`client_secret` at `authx[.sandbox].alpaca.markets` and caches
the token behind a `Mutex`. It refreshes the token about 60s before `expires_in`, and once more if
a request gets a 401. Legacy key/secret Basic auth is supported with
`Alpaca::Broker::Client.new(key_id:, secret_key:)`. `private_key_jwt` client assertions are
accepted as a callable (`client_assertion: -> { MyJwt.sign(...) }`) so the gem doesn't need a
JWT dependency.

## 7. Tooling

- **Ruby ≥ 3.3** (3.2 reached EOL in March 2026). Develop on 4.0.x and test on 3.3, 3.4 and 4.0
  in GitHub Actions. Remove `.travis.yml`.
- Runtime dependencies: `faraday ~> 2.9`, `faraday-retry ~> 2.2`, `bigdecimal`.
  Optional (streaming only): `async-websocket`, `msgpack`.
- Development dependencies: `rspec`, `webmock`, `simplecov`, `standard` (linting), `async-websocket`,
  `msgpack`, `yard`. Remove `byebug` and `rb-readline`, and use `debug` instead.
- RBS signatures in `sig/` for the public surface, checked with `steep` in CI (stretch goal).
- YARD docs on every public method, each linking to its Alpaca reference page.

## 8. Testing strategy

- **Unit (default, offline):** WebMock stubs with JSON fixtures in `spec/fixtures/`. Fixtures
  are taken from the OpenAPI `example`s where they exist and redacted from real responses
  otherwise. Each resource spec checks the request (verb, path, query, body, headers) and the
  parsed result.
- **Contract:** a shared example validates that each resource's outgoing request matches the
  vendored OpenAPI operation (path template, param names, enum values). This catches drift.
- **Live (opt-in):** `ALPACA_LIVE=1 bundle exec rspec --tag live` runs against paper,
  data.sandbox and broker sandbox with real keys from env. It runs nightly in CI with secrets
  and never on PRs. VCR is dropped. Its cassettes were the main reason the old suite went stale.
- **Streaming:** an in-process fake WebSocket server (Async) replays scripted frames, and one
  live test uses the always-on `v2/test` stream with `FAKEPACA`.
- Coverage gate: 95% lines and 100% of `rake openapi:coverage`.

## 9. Delivery plan

Each milestone is a releasable `2.0.0.alphaN` / `betaN`:

1. **Foundation:** gemspec/CI/Ruby bump, `Alpaca::Model`, HTTP and auth layer, errors, retry
   policy, pagination, operation registry plus `rake openapi:coverage`, OCC symbol helper.
2. **Trading API:** all 58 operations, including options, watchlists, crypto wallets, locates and tokenization.
3. **Broker core:** accounts, KYC, documents, agreements, funding (ACH, transfers, recipient
   banks), journals, trading-on-behalf, OAuth, assets/calendar/clock.
4. **Broker extended:** rebalancing, instant funding, JIT, funding wallets, crypto funding,
   ACATS, IPO, FPSL, reporting, tokenization, cash interest, IRA, country info, logos.
5. **Market Data API:** all 42 operations, `Series`, and Data-based tick models.
6. **Streaming:** trade updates, stock/crypto/options/news market data, and SSE (Trading + Broker events).
7. **Polish:** README rewritten around tasks, YARD site, RBS, `UPGRADING.md` mapping 0.x calls
   to 2.0, and the 2.0.0 release.

## 10. Decisions (resolved 2026-10-19)

1. **Require path / namespace:** `require "alpaca"` and `Alpaca::`. The gem name stays `alpaca-trade-api`.
2. **Minimum Ruby:** 3.3.
3. **Streaming dependencies:** optional (`async-websocket`, `msgpack`), loaded only by `require "alpaca/streaming"`.
4. **Numerics:** `BigDecimal` everywhere, market data included.
5. **Broker:** in active use, so it's moved up to milestones 3–4, right after Trading.
6. **Retries:** `faraday-retry`, configured with the method/status rules in §6.2 (`methods:` for
   idempotent verbs, `retry_if:` for 429 and requests carrying an `Idempotency-Key`).

## 11. As built: deviations from this proposal

The README is the reference for the final API. These are the places it differs from §5:

- **Account API:** `trading.account` returns the model. Configuration and history are client
  methods: `account_configuration`, `update_account_configuration`, `portfolio_history`, and
  `activities.list`.
- **Option contracts:** `trading.option_contracts.list/find` (not `trading.options.contracts`).
  The OCC helper is `Alpaca::OptionSymbol`, not `Alpaca::Options::Symbol`, so it can't shadow `::Symbol`.
- **Pagination:** there is no `Series#limit`. Use `first(n)` and `each_page`; `limit:` stays the
  API's page size.
- **Single vs multi symbol:** a String uses the single-symbol endpoint and an Array uses the
  multi-symbol one, so both operations are implemented and covered. "Latest" and snapshot calls
  return one record for a String and a Hash for an Array.
- **Market data feed:** the client's `feed` applies to stock endpoints only. Options take
  `feed: :opra/:indicative` per call, and auctions are SIP-only.
- **Broker funding:** flat, account-first resources (`broker.ach_relationships.create(account_id, ...)`,
  `broker.transfers`, `broker.recipient_banks`, `broker.journals`, ...). The extended programs
  are `broker.instant_funding`, `jit`, `funding_wallets`, `acats`, `rebalancing.{portfolios,subscriptions,runs}`,
  `ipos`, `fpsl`, `reporting` and `oauth`.
- **Broker per-account resources:** `broker.trading(id)`, `broker.crypto_funding(id)`,
  `broker.tokenization(id)`. These reuse the Trading classes with a different path scope.
- **SSE:** `Alpaca::EventStream` is in core (no extra dependencies). Unbounded streams resume with
  `since_id` (or `since_ulid` on legacy `/v1/events/*`).
- **WebSocket handlers:** `on_trade(*symbols)`, `on_quote`, `on_bar`, `on_updated_bar`,
  `on_daily_bar`, `on_status`, `on_luld`, `on_correction`, `on_cancel_error`, `on_imbalance`,
  `on_orderbook`, `on_news`. Registering a handler also subscribes to its symbols.
  `TradeUpdates#on(*events)` / `#on_update`.
- **Skipped on purpose:** legacy `/v2/clock` and `/v2/calendar` (Trading) and `/v1/clock` and
  `/v1/calendar` (Broker), which are superseded by the v3 / v2 multi-market endpoints.
- **Retries:** implemented with faraday-retry (§10.6), plus one 401 re-authentication for
  refreshable Broker tokens.
- **RBS signatures and a YARD site** (milestone 7) are not done yet.

