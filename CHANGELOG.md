# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - Unreleased
A ground-up rewrite. 2.0 is **not** backwards compatible with 0.x; see `docs/v2-proposal.md`.

### Fixed
- Prevent HTTP retries from replaying server-sent event streams after data has already been delivered.
- Honor custom Faraday adapters for API and Broker AuthX token requests, including configured timeouts and logging.
- Lazily paginate Broker transfer and instant-funding lists, and cache market-data clients independently by feed.
- Reject malformed option symbols and invalid option-symbol components before formatting them.

### Added
- `require "alpaca"` with three clients: `Alpaca::Trading::Client`, `Alpaca::Broker::Client` and
  `Alpaca::MarketData::Client` (plus `Alpaca.trading`, `Alpaca.broker`, `Alpaca.market_data`).
- Every documented Trading, Broker and Market Data REST operation (tracked against Alpaca's
  OpenAPI specs with `rake openapi:coverage`), including options (contracts, multi-leg orders,
  exercise), crypto funding, locates, tokenization, watchlists, Broker onboarding, funding,
  journals, ACATS, rebalancing, IPOs, FPSL and reporting.
- Lazy auto-pagination for every paginated list (`Alpaca::Collection`).
- Server-Sent Event streams with automatic resume (`broker.events.*`, `trading.events.activities`).
- Optional WebSocket streaming (`require "alpaca/streaming"`): trade updates and market data.
- Typed models: every non-integer number is a `BigDecimal`, timestamps are `Time`, enums are Symbols;
  unknown fields remain readable.
- Structured errors (`Alpaca::APIError` subclasses with `status`, `code`, `request_id`).
- Safe retries via faraday-retry (429s always; other failures only for idempotent requests).
- Broker client-credentials (authx) tokens with caching and refresh; Alpaca Connect OAuth tokens.
- `Alpaca::OptionSymbol` to build and parse OCC option symbols.

### Changed
- Requires Ruby >= 3.3 and Faraday 2.
- Environment variables are now `APCA_API_KEY_ID` / `APCA_API_SECRET_KEY` (the 0.x
  `ALPACA_API_*` names are still read as a fallback).

### Removed
- The 0.x API (`Alpaca::Trade::Api::Client`, `Alpaca::Market::*`) and the v1 market data endpoints.

## [0.10.0] - 2023-05-x
### Added
- Started to implement methods for Market Data API, see `Alpaca::Market::StockClient`.

## [0.9.0] - 2022-04-10
### Added
- Added trail_percent and trail_price to orders

## [0.8.0] - 2021-04-20
### Added
- Added fractionable and notional orders

## [0.7.0] - 2021-02-27
### Added
- Support for `faraday` 1.x.

## [0.6.0] - 2020-05-26
### Added
- Implemented Client#account_activities. Thanks @travishooper.

## [0.5.0] - 2020-05-25
### Added
- Implemented Client#last_trade. Thanks @nathanworden.

## [0.4.1] - 2020-04-25
### Fixed
- Added explicit `BigDecimal` require.

## [0.4.0] - 2020-02-16
### Added
- Supporting [Bracket Orders](https://docs.alpaca.markets/trading-on-alpaca/orders/#bracket-orders)
- Validating time frame in Client#bars

## [0.3.0] - 2019-09-19
### Added
- Implemented new endpoints:
  * Client#cancel_orders
  * Client#close_position
  * Client#close_positions
  * Client#replace_order
- Added limit as a parameter to Client#bars
- Renamed Clock#open to Clock#is_open and fixed assignment.

## [0.2.0] - 2019-07-10
### Added
- Implemented Client#calendar.
- Implemented Client#clock.
- Added Client#assets.
- Implemented new methods in Client: new_order, order, orders, position, positions.
- Implemented Client#cancel_order.

## [0.1.0] - 2019-07-04
### Added
- First version of gem.
- Includes support for account, asset, and data endpoints.
