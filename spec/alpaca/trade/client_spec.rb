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

  describe '#account' do
    it 'returns an Account object', :vcr do
      account = subject.account
      expect(account.status).to eq('ACTIVE')
      expect(account.currency).to eq('USD')
      expect(account.pattern_day_trader).to be_falsy
    end

    it 'raise UnauthorizedError when status code is 401', :vcr do
      subject = described_class.new(key_secret: 'wrong')
      expect { subject.account }.to raise_error(Alpaca::Trade::Api::UnauthorizedError)
    end
  end

  describe '#asset' do
    it 'returns an Asset object', :vcr do
      asset = subject.asset(symbol: 'CRM')
      expect(asset.asset_class).to eq('us_equity')
      expect(asset.tradable).to be_truthy
    end
  end
end
