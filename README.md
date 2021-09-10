# Alpaca::Trade::Api

This is a high-level Ruby wrapper for [Alpaca trading API](https://docs.alpaca.markets/api-documentation/). This implementation *only* supports the Web API v2 API, there is no plan to support Web API v1.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'alpaca-trade-api'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install alpaca-trade-api

## Usage

### Configuration

By default, the library is configured to use the Paper Trading host - `https://paper-api.alpaca.markets` - as the endpoint it connects to, and loads both the key id and secret key from the following environment variables: `ALPACA_API_KEY_ID` and `ALPACA_API_SECRET_KEY`. To configure the library differently:

```ruby
Alpaca::Trade::Api.configure do |config|
  config.endpoint = 'https://api.alpaca.markets'
  config.key_id = 'A_KEY_ID'
  config.key_secret = 'A_S3CRET'
end
```


### Example

Here's an example on how to use the library to read details of an account's orders in paper trading.

```ruby
require 'alpaca/trade/api'

Alpaca::Trade::Api.configure do |config|
  config.endpoint = 'https://paper-api.alpaca.markets'
  config.key_id = 'xxxxxxxx'
  config.key_secret = 'xxxxx'
end

client =  Alpaca::Trade::Api::Client.new
puts client.orders.last.inspect
```

### Supported endpoints

Here's a table with all currently supported endpoints in this library:

| Object                                                                                        | Action                                 | Method                                    |
|-----------------------------------------------------------------------------------------------|----------------------------------------|-------------------------------------------|
| [Account](https://docs.alpaca.markets/api-documentation/api-v2/account/)                      | [GET] Get the account                  | Client#account                            |
| [Account Activities](https://docs.alpaca.markets/api-documentation/api-v2/account-activities) | [GET] Get a list of account activities | Client#account_activities(activity_type:) |
| [Orders](https://docs.alpaca.markets/api-documentation/api-v2/orders/)                        | [GET] Get a list of orders             | Client#orders                             |
|                                                                                               | [POST] Request a new order             | Client#new_order                          |
|                                                                                               | [GET] Get an order                     | Client#order(id:)                         |
|                                                                                               | [GET] Get an order by client order id  | Client#order(id:)                         |
|                                                                                               | [PATCH] Replace an order               | Client#replace_order                      |
|                                                                                               | [DELETE] Cancel all orders             | Client#cancel_orders                      |
|                                                                                               | [DELETE] Cancel an order               | Client#cancel_order(id:)                  |
| [Positions](https://docs.alpaca.markets/api-documentation/api-v2/positions/)                  | [GET] Get open positions               | Client#positions                          |
|                                                                                               | [GET] Get an open position             | Client#position(symbol:)                  |
|                                                                                               | [DELETE] Close all positions           | Client#close_positions                    |
|                                                                                               | [DELETE] Close a position              | Client#close_position(symbol:)            |
| [Assets](https://docs.alpaca.markets/api-documentation/api-v2/assets/)                        | [GET] Get assets                       | Client#assets                             |
|                                                                                               | [GET] Get assets/:id                   | Client#asset(symbol:)                     |
|                                                                                               | [GET] Get an asset                     | Client#asset(symbol:)                     |
| [Calendar](https://docs.alpaca.markets/api-documentation/api-v2/calendar/)                    | [GET] Get the calendar                 | Client#calendar(start_date:, end_date:)   |
| [Clock](https://docs.alpaca.markets/api-documentation/api-v2/clock/)                          | [GET] Get the clock                    | Client#clock                              |
| [Bars](https://alpaca.markets/docs/api-documentation/api-v2/market-data/alpaca-data-api-v2/historical/#bars)                | [GET] Get a list of bars               | Client#bars(timeframe:, symbol:, start:, end_:, limit:)   |

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ccjr/alpaca-trade-api.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
