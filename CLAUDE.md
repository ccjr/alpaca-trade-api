# CLAUDE.md

Ruby client for the Alpaca APIs (Trading, Broker, Market Data, plus WebSocket/SSE streaming).
Gem name: `alpaca-trade-api`, required as `require "alpaca"`. Maintainer: Cloves Carneiro Jr.

**Status:** 2.0 rewrite implemented on the `v2` branch (all 263 documented REST/SSE operations
covered; 4 legacy ones skipped on purpose). Backwards compatibility with 0.x is NOT
a goal. Design and milestones: `docs/v2-proposal.md`.

## Commands

```sh
bundle exec rspec                       # full suite (enforces 95% line coverage)
bundle exec rspec spec/alpaca/trading   # a subset (coverage gate is skipped)
bundle exec standardrb [--fix]          # lint (StandardRB, ruby_version 3.3)
bundle exec rake openapi:coverage       # documented operations vs implemented ones
bundle exec rake openapi:update         # refresh openapi/*.json from Alpaca, then git diff
bundle exec rake                        # spec + standard + openapi:coverage
```

Ruby: develop on `.ruby-version` (4.0.x); must support >= 3.3 (rbenv has 3.3.6 and 3.4.x).

## Architecture (lib/alpaca)

- `http/connection.rb` — one Faraday 2 connection per client. Auth headers, JSON encoding,
  faraday-retry (idempotent verbs; POST/PATCH only on 429 or with `Idempotency-Key`),
  status → error class mapping, single 401 re-auth for refreshable (Broker token) auth.
- `http/auth.rb` — `ApiKey`, `Bearer` (Connect), `Basic` (legacy Broker), `ClientCredentials`
  (authx token, cached + refreshed). Each also provides `stream_credentials`.
- `http/params.rb` — wire encoding: BigDecimal → "1.5", Time → RFC 3339 UTC, Date → ISO,
  arrays → comma-joined in queries, nils dropped, path segments escaped.
- `http/response.rb` — `data` parses JSON with `decimal_class: BigDecimal`; `request_id`, `rate_limit`.
- `model.rb` — `Alpaca::Model`: `attribute :name, :decimal|:integer|:time|:date|:symbol|:boolean|:string|:raw|Klass|[type]`.
  Undeclared fields stay readable (`model.field`, `model[:field]`). Enum-like fields → Symbols.
  Every non-integer number → BigDecimal (user decision: BigDecimal everywhere, market data too).
- `collection.rb` — lazy auto-paginating `Enumerable` (`Collection::Page`).
- `resource.rb` — base for endpoint groups. `operation trading: "opId", broker: "opId"` before a
  method registers it in `OperationRegistry` (drives `rake openapi:coverage`). Private helpers:
  `http_get/post/put/patch/delete(path, query:, body:, model:, idempotency_key:)`,
  `paginate` (page_token/next_page_token), `paginate_by_last_id`, `download` (binary),
  `path(base, *segments)` and `scoped(relative, *segments)` (prefix with `scope`).
  Never name private helpers `get`/`post`/`request`… — public methods like `delete` would clash.
- `models/` — shared API objects (`Alpaca::Order`, `Alpaca::Position`, ...).
- `trading/` — Trading resources. Resources take a `scope` so Broker reuses them:
  `"/v2"` for Trading vs `"/v1/trading/accounts/{id}"` (orders, positions, watchlists, account)
  or `"/v1"`/`"/v1/accounts/{id}"` (assets, options, crypto funding, tokenization).
  `Trading::AccountScope` holds the account-level accessors shared with Broker.
- `broker/` — Broker resources. Per-account trading via `Broker::AccountTrading` (includes
  `Trading::AccountScope`); `Broker::Assets/CryptoFunding/Tokenization` subclass the Trading ones.
- `market_data/` — Market Data resources. Records are `MarketData::Record` subclasses declared
  with `field :readable_name, "wire_key", type` (raw keys stay readable via `#[]`). `Series` is
  a Collection with `to_h` grouping by symbol. String symbol → single-symbol endpoint, Array →
  multi-symbol endpoint. The client `feed` is applied to stock endpoints only.
- `event_stream.rb` — SSE parser + `EventStream` (resumable, used by `*/events` resources);
  `HTTP::Connection#stream` does the Faraday `on_data` streaming.
- `streaming/` (opt-in, `require "alpaca/streaming"`) — `Stream` base (auth, reconnect with
  backoff, resubscribe, handlers), `TradeUpdates`, `MarketData` (stocks/crypto/options/news/test),
  `AsyncTransport` (async-websocket; cross-thread writes go through a queue) and `MsgpackCodec`.
- `operation_registry.rb` / `openapi_coverage.rb` — registry + coverage report. Use
  `OperationRegistry.skip(api, id, reason)` for deliberately unimplemented operations.
- `rakelib/model_generator.rb` — `rake "openapi:model[broker,Schema,ClassName]"` drafts a model
  from an OpenAPI schema (review by hand before committing).

### Conventions for new endpoints

1. Find the operation in `openapi/<api>-api.json` (paths, params, schemas, examples).
2. Required inputs → positional args / required keywords; optional filters → `**params`
   passed straight through (forward compatible). No client-side validation beyond that.
3. Declare `operation <api>: "<operationId>"` right above the method.
4. Return models (`model:`), arrays (`|| []` for empty bodies), `true` for bodyless success,
   or a `Collection` for paginated lists.
5. Spec it in `spec/alpaca/<api>/` with WebMock (`stub_json`, `json_body`), preferably using
   `openapi_example(api, path, verb, name)` fixtures. `spec/support/openapi_contract.rb`
   automatically fails a test whose request path/verb/query/body keys aren't in the spec
   (opt out per example with `:skip_contract` only for deliberately off-spec requests).

## Sources of truth for the API (use these, not memory)

Vendored OpenAPI 3.1 specs in `openapi/` (refresh with `rake openapi:update`):

| API          | Spec                                                     | Hosts (live / test)                                                              |
|--------------|----------------------------------------------------------|----------------------------------------------------------------------------------|
| Trading      | https://docs.alpaca.markets/openapi/trading-api.json     | `api.alpaca.markets` / `paper-api.alpaca.markets`                                |
| Broker       | https://docs.alpaca.markets/openapi/broker-api.json      | `broker-api.alpaca.markets` / `broker-api.sandbox.alpaca.markets`                |
| Market Data  | https://docs.alpaca.markets/openapi/market-data-api.json | `data.alpaca.markets` / `data.sandbox.alpaca.markets`                            |

Prose docs are available as raw markdown by appending `.md` to any docs URL, e.g.
`https://docs.alpaca.markets/us/docs/options-level-3-trading.md`. Full index:
`https://docs.alpaca.markets/us/llms.txt`. Streaming (WebSocket) APIs are NOT in the OpenAPI
specs — read `websocket-streaming.md` (trade_updates), `streaming-market-data.md`,
`real-time-{stock-pricing,crypto-pricing,option}-data.md`, `streaming-real-time-news.md`.

## Authentication cheat sheet

- **Trading + Market Data (individual):** headers `APCA-API-KEY-ID` / `APCA-API-SECRET-KEY`.
- **Alpaca Connect (OAuth2 on behalf of a user):** `Authorization: Bearer <token>`.
- **Broker:** client-credentials token from `https://authx[.sandbox].alpaca.markets/v1/oauth2/token`
  (valid ~15 min — cache and refresh, never fetch per request). Legacy Broker keys use HTTP Basic.
- **WebSockets:** auth via handshake headers or an `{"action":"auth",...}` message within 10s.
  Broker token → `key: "access_token"`; Connect token → `key: "oauth"`.
- Env vars: `APCA_API_KEY_ID`, `APCA_API_SECRET_KEY` (falls back to 0.x `ALPACA_API_*`),
  `APCA_API_OAUTH_TOKEN`, `APCA_API_BASE_URL`, `APCA_BROKER_CLIENT_ID/SECRET`,
  `APCA_BROKER_API_KEY_ID/SECRET_KEY`, `APCA_BROKER_SANDBOX`, `APCA_DATA_FEED`.

## API quirks worth remembering

- Trading money/quantity fields are JSON **strings** (`"qty": "1.5"`); market data prices are
  JSON numbers. Timestamps are RFC 3339 with nanoseconds in market data.
- Market data multi-symbol endpoints return `{ "bars": { "AAPL": [...], ... }, "next_page_token": ... }`;
  `limit` applies across all symbols, so one symbol can span several pages.
- Pagination styles differ: market data and most broker lists use `page_token` (+`limit`);
  account activities use `page_token` = id of the last item; `/v2/orders` pages with
  `before_order_id`/`after_order_id` (Broker orders: by `until`/`after` submission time).
- Some list endpoints are documented as returning one object but return arrays (crypto
  wallets/transfers/whitelists) — wrap with `Array(Model.build(...))`.
- Options: `order_class: "mleg"` with `legs: [{symbol, ratio_qty, side, position_intent}]`;
  qty must be whole, no `notional`, `time_in_force` only `day`/`gtc`. OCC symbols look like
  `AAPL250117C00190000` (`Alpaca::OptionSymbol`).
- Option WebSocket stream is **msgpack only**. `trade_updates` on the trading host sends binary frames.
- `v2/clock` and `v2/calendar` (Trading) / `v1/clock`, `v1/calendar` (Broker) are "Legacy";
  the gem uses `v3/clock`, `v3/calendar/{market}` (Broker: `v2/...`).
- Rate limits: 429 with `X-RateLimit-Limit/Remaining/Reset` (Unix seconds) headers.

## Testing

- RSpec + WebMock only (no VCR, no live calls in the default suite). Fixtures come from the
  OpenAPI examples where possible. Never commit real keys, account numbers or payloads.
- `max_retries` is forced to 0 in specs; retry specs opt back in and stub `sleep`.
- WebSocket specs use `spec/support/fake_transport.rb` (scripted frames; `FakeTransport::Raw`
  for exact payload/binary frames). `spec/alpaca/streaming/async_transport_spec.rb` runs a real
  local async-websocket server and must disable WebMock's async-http adapter while it runs.
- SSE specs stub `text/event-stream` bodies; queries need `with(query: ...)`/`hash_including`.
- On Ruby 3.3, async logs harmless "Attempt to unlock a mutex which is not locked" warnings
  when a WebSocket closes (fiber-scheduler quirk, absent on 3.4+).

## Conventions

- `# frozen_string_literal: true` at the top of every Ruby file; StandardRB style.
- Keyword arguments named exactly like Alpaca's JSON fields (`until:` is fine as a keyword).
- Runtime deps: faraday, faraday-retry, bigdecimal only. Streaming deps (async-websocket,
  msgpack) are optional and must only be required by `require "alpaca/streaming"`.
- Update `CHANGELOG.md` (Keep a Changelog format) with every user-visible change.
- Git: work on `v2`; commit only when asked.
