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
  config.endpoint = 'https://api.alapca.markets'
  config.key_id = 'A_KEY_ID'
  config.key_secret = 'A_S3CRET'
end
```

### Account

TODO: Write usage instructions here

### Asset

TODO: Write usage instructions here

### Trading

TODO: Write usage instructions here

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ccjr/alpaca-trade-api.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
