# frozen_string_literal: true

RSpec.describe Alpaca::Trade::Api::Client do
  describe '.initialize' do
    it 'defaults to configuration' do
      expect(subject.endpoint).to eq(Alpaca::Trade::Api.configuration.endpoint)
      expect(subject.key_id).to eq(Alpaca::Trade::Api.configuration.key_id)
      expect(subject.key_secret).to eq(Alpaca::Trade::Api.configuration.key_secret)
    end

    it 'accepts overwriting configuration' do
      client = described_class.new(endpoint: 'a', key_id: 'b', key_secret: 'c')
      expect(client.endpoint).to eq('a')
      expect(client.key_id).to eq('b')
      expect(client.key_secret).to eq('c')
    end
  end

  context 'generic errors' do
    it 'raises UnauthorizedError when status code is 401', :vcr do
      subject = described_class.new(key_secret: 'wrong')
      expect { subject.account }.to raise_error(Alpaca::Trade::Api::UnauthorizedError)
    end

    it 'raises RateLimitedError when status code is 429', :vcr do
      expect_any_instance_of(Faraday::Response).to receive(:status).at_least(:once).and_return(429)
      expect { subject.account }.to raise_error(Alpaca::Trade::Api::RateLimitedError)
    end

    it 'raises InternalServerError when status code is 500', :vcr do
      expect_any_instance_of(Faraday::Response).to receive(:status).at_least(:once).and_return(500)
      expect { subject.account }.to raise_error(Alpaca::Trade::Api::InternalServerError)
    end
  end

  describe '#account' do
    it 'returns an Account object', :vcr do
      account = subject.account
      expect(account.status).to eq('ACTIVE')
      expect(account.currency).to eq('USD')
      expect(account.pattern_day_trader).to be_falsy
    end
  end

  describe '#account_activities' do
    it 'returns an Array of TradeActivity objects', :vcr do
      trade_activities = subject.account_activities(activity_type: 'FILL')
      expect(trade_activities).to be_an(Array)
      expect(trade_activities.first).to be_an(Alpaca::Trade::Api::TradeActivity)
    end

    it 'returns an Array of NonTradeActivity objects', :vcr do
      trade_activities = subject.account_activities(activity_type: 'DIV')
      expect(trade_activities).to be_an(Array)
      expect(trade_activities.first).to be_an(Alpaca::Trade::Api::NonTradeActivity)
    end

    it 'raises an exception when the activity type requested is invalid', :vcr do
      expect { subject.account_activities(activity_type: 'INVALID') }.to raise_error(Alpaca::Trade::Api::InvalidActivityType)
    end
  end

  describe '#asset' do
    it 'returns an Asset object', :vcr do
      asset = subject.asset(symbol: 'CRM')
      expect(asset.asset_class).to eq('us_equity')
      expect(asset.tradable).to be_truthy
    end
  end

  describe '#assets' do
    it 'returns an Array of Asset objects', :vcr do
      assets = subject.assets
      expect(assets).to be_an(Array)
      expect(assets.first).to be_an(Alpaca::Trade::Api::Asset)
    end

    it 'filters assets by status and asset_class', :vcr do
      assets = subject.assets(status: 'active', asset_class: 'us_equity')
      expect(assets).to be_an(Array)
      expect(assets.first).to be_an(Alpaca::Trade::Api::Asset)
    end
  end

  describe '#bars' do
    it 'returns Bar objects for one symbol', :vcr do
      bars = subject.bars(timeframe: '15Min', symbol:'QQQ', start: Time.new(2021, 8, 26, 14, 0, 0,  "+00:00"), end_: Time.new(2021, 9, 6, 14, 0, 0,  "+00:00"), limit: 3)
      puts bars.inspect
      expect(bars).to be_an(Array)

      bar = bars.first
      expect(bar).to be_an(Alpaca::Trade::Api::Bar)
      expect(bar.close).to eq(374.25)
    end

    # Deprecated (https://alpaca.markets/docs/api-documentation/api-v2/market-data/alpaca-data-api-v2/historical/#bars)

    # it 'returns Bar objects for multiple symbols', :vcr do
    #   bars = subject.bars('1D', %w[CRM FB AMZN])
    #   expect(bars['FB']).to be_an(Array)
    #
    #   bar = bars['AMZN'].first
    #   expect(bar).to be_an(Alpaca::Trade::Api::Bar)
    # end

    it 'accepts limit as parameter', :vcr do
      bars = subject.bars(timeframe: '15Min', symbol:'QQQ', start:Time.new(2021, 8, 26, 14, 0, 0,  "+00:00"), end_: Time.new(2021, 9, 6, 14, 0, 0,  "+00:00"), limit: 3)
      expect(bars).to be_an(Array)
      expect(bars.size).to eq(3)
    end

    it 'doesnt accept invalid time frames' do
      expect {
        subject.bars('1FOO', ['CRM'])
      }.to raise_error(ArgumentError)
    end
  end

  describe '#calendar' do
    it 'returns Calendar objects', :vcr do
      market_calendar = subject.calendar(start_date: Date.new(2019,6,1), end_date: Date.new(2019,7,1))
      expect(market_calendar).to be_an(Array)
      expect(market_calendar.size).to eq(21)
      expect(market_calendar.first).to be_an(Alpaca::Trade::Api::Calendar)
    end
  end

  describe '#cancel_order' do
    let(:existing_order_id) { '1df53539-385c-4a5d-9c02-565352ac60b0' }
    let(:order_id) { 'aefc84eb-247f-4782-a811-96f5ba1b72ff' }
    let(:invalid_id) { '001c0b29-5bc9-45c4-bd32-5ba323c997b3' }

    it 'cancels an existing order', :vcr do
      expect { subject.cancel_order(id: existing_order_id) }.to_not raise_error
    end

    it 'raises an exception when order id is invalid', :vcr do
      expect { subject.cancel_order(id: invalid_id) }.to raise_error(Alpaca::Trade::Api::InvalidOrderId)
    end
  end

  describe '#cancel_orders' do
    let(:existing_order_id) { '9b36cef2-8f9d-4499-a599-77de3e482b6f' }

    it 'cancels existing orders', :vcr do
      cancelled_orders = subject.cancel_orders
      expect(cancelled_orders).to be_an(Array)

      order_response = cancelled_orders.last
      expect(order_response['id']).to eq(existing_order_id)
      expect(order_response['status']).to eq(200)
      expect(order_response['body']).to be_an(Alpaca::Trade::Api::Order)
    end

    it 'returns an empty array when there are no orders', :vcr do
      expect(subject.cancel_orders).to eq([])
    end
  end

  describe '#close_position' do
    it 'raises when there are no positions for symbol', :vcr do
      expect { subject.close_position(symbol: 'CRM') }.to raise_error(Alpaca::Trade::Api::NoPositionForSymbol)
    end

    it 'closes an open position', :vcr do
      closed_position = subject.close_position(symbol: 'AIV')

      expect(closed_position).to be_an(Alpaca::Trade::Api::Position)
      expect(closed_position.symbol).to eq('AIV')
    end
  end

  describe '#close_positions' do
    let(:existing_position_symbol) { 'AIV' }

    it 'closes all open positions', :vcr do
      closed_positions = subject.close_positions
      expect(closed_positions).to be_an(Array)

      position_response = closed_positions.first
      expect(position_response['symbol']).to eq(existing_position_symbol)
      expect(position_response['status']).to eq(200)
      expect(position_response['body']).to be_an(Alpaca::Trade::Api::Position)
    end

    it 'returns an empty array when there are no positions', :vcr do
      expect(subject.close_positions).to eq([])
    end
  end

  describe '#last_trade' do
    it 'return last trade information', :vcr do
      last_trade = subject.last_trade(symbol: 'TSLA')
      expect(last_trade).to be_an(Alpaca::Trade::Api::LastTrade)
      expect(last_trade.status).to eq('success')
      expect(last_trade.symbol).to eq('TSLA')
      expect(last_trade.last).to be_an(Hash)
      expect(last_trade.last.keys.sort).to eq(["cond1", "cond2", "cond3", "cond4",
        "exchange", "price", "size", "timestamp"])
    end

    it 'raises InvalidRequest on bogus symbol', :vcr do
      expect { subject.last_trade(symbol: 'FOOBAR') }.to raise_error(Alpaca::Trade::Api::InvalidRequest)
    end
  end

  describe '#new_order' do
    it 'places a new Order', :vcr do
      order = subject.new_order(symbol: 'AAPL',
                                qty: 5,
                                side: 'buy',
                                type: 'limit',
                                time_in_force: 'day',
                                limit_price: 200,
                                extended_hours: true,
                                client_order_id: 'MY_ORDER_ID')
      expect(order).to be_an(Alpaca::Trade::Api::Order)
      expect(order.id).to_not be_nil
    end

    it 'supports bracket orders', :vcr do
      order = subject.new_order(symbol: 'AAPL',
                                qty: 5,
                                side: 'buy',
                                type: 'limit',
                                order_class: 'bracket',
                                time_in_force: 'day',
                                limit_price: 325,
                                take_profit: { limit_price: 335 },
                                stop_loss: { stop_price: 315 },
                                client_order_id: 'BRACKET_ORDER_ID')
      expect(order).to be_an(Alpaca::Trade::Api::Order)
      expect(order.order_class).to eq('bracket')
      expect(order.legs).to be_an(Array)
      expect(order.legs.size).to eq(2)
      order.legs.each { |leg| expect(leg).to be_an(Alpaca::Trade::Api::Order) }
    end

    it 'supports fractionable orders', :vcr do
        # require 'pry'; binding.pry
      order = subject.new_order(symbol: 'AAPL',
                                qty: 1.8,
                                side: 'buy',
                                type: 'market',
                                time_in_force: 'day')
      expect(order).to be_an(Alpaca::Trade::Api::Order)
      expect(order.id).to_not be_nil
    end

    it 'supports notional orders', :vcr do
      order = subject.new_order(symbol: 'AAPL',
                                notional: 500,
                                side: 'buy',
                                type: 'market',
                                time_in_force: 'day')
      expect(order).to be_an(Alpaca::Trade::Api::Order)
      expect(order.id).to_not be_nil
    end

    it 'raises an exception when buying power is not sufficient', :vcr do
      expect { subject.new_order(symbol: 'AAPL',
                                 qty: 5_000,
                                 side: 'buy',
                                 type: 'limit',
                                 time_in_force: 'day',
                                 limit_price: 200,
                                 extended_hours: true) }.to raise_error(Alpaca::Trade::Api::InsufficientFunds)
    end

    it 'raises an exception when required parameters are not provided', :vcr do
      expect { subject.new_order(symbol: 'AAPL',
                                 qty: 5,
                                 side: 'buy',
                                 type: 'limit',
                                 time_in_force: 'day',
                                 extended_hours: true,
                                 client_order_id: 'MY_ORDER_ID_2') }.to raise_error(Alpaca::Trade::Api::MissingParameters)
    end
  end

  describe '#replace_order' do
    let(:canceled_order_id) { '7ab88b48-b57a-48bf-aa58-89496b23757d' }
    let(:invalid_id) { '001c0b29-5bc9-45c4-bd32-5ba323c997b3' }
    let(:valid_id) { '1c7490e3-a3fb-4f33-aa93-d0194e675bfa' }

    it 'updates an Order', :vcr do
      order = subject.replace_order(id: valid_id,
                                    qty: 100,
                                    limit_price: 25.25,
                                    client_order_id: 'MY_ORDER_ID_3')
      expect(order).to be_an(Alpaca::Trade::Api::Order)
      expect(order.limit_price).to eq('25.25')
      expect(order.status).to eq('new')
    end

    it 'raises an exception when order id is invalid', :vcr do
      expect {
        subject.replace_order(id: invalid_id,
                              qty: 105,
                              time_in_force: 'gtc',
                              stop_price: 25.1)
      }.to raise_error(Alpaca::Trade::Api::InvalidOrderId)
    end

    it 'raises an exception when buying power is not sufficient', :vcr do
      expect {
        subject.replace_order(id: valid_id,
                              qty: 100_000,
                              limit_price: 30)
      }.to raise_error(Alpaca::Trade::Api::InsufficientFunds)
    end

    it 'raises an exception when trying to replace orders that are not open', :vcr do
      expect {
        subject.replace_order(id: canceled_order_id,
                              qty: 200)
      }.to raise_error(Alpaca::Trade::Api::InvalidRequest)
    end
  end

  describe '#clock' do
    it 'returns the market clock', :vcr do
      clock = subject.clock
      expect(clock).to be_an(Alpaca::Trade::Api::Clock)
      expect(clock.is_open).to be_falsey
    end
  end

  describe '#order' do
    let(:invalid_id) { '001c0b29-5bc9-45c4-bd32-5ba323c997b3' }
    let(:valid_id) { 'f08bfc92-c922-41f9-8166-3657e5bedef0' }

    it 'returns an Order object', :vcr do
      order = subject.order(id: valid_id)
      expect(order).to be_an(Alpaca::Trade::Api::Order)
    end

    it 'raises an exception when order id is invalid', :vcr do
      expect { subject.order(id: invalid_id) }.to raise_error(Alpaca::Trade::Api::InvalidOrderId)
    end
  end

  describe '#orders' do
    it 'returns an Array of Order objects', :vcr do
      orders = subject.orders(status: 'all', limit: 5)
      expect(orders).to be_an(Array)
      expect(orders.size).to eq(5)
      expect(orders.first).to be_an(Alpaca::Trade::Api::Order)
    end
  end

  describe '#position' do
    it 'returns a Position object', :vcr do
      position = subject.position(symbol: 'FB')
      expect(position).to be_an(Alpaca::Trade::Api::Position)
    end

    it 'raises an exception when position is not found for symbol', :vcr do
      expect { subject.position(symbol: 'CRM') }.to raise_error(Alpaca::Trade::Api::NoPositionForSymbol)
    end
  end

  describe '#positions' do
    it 'returns an Array of Position objects with open positions', :vcr do
      positions = subject.positions
      expect(positions).to be_an(Array)
      expect(positions.first).to be_an(Alpaca::Trade::Api::Position)
    end
  end
end
