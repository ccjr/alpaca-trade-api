# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0] - Unreleased
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
