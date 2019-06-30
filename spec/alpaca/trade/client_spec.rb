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

  describe '#asset' do
    it 'returns an Asset object', :vcr do
      asset = subject.asset(symbol: 'CRM')
      expect(asset.asset_class).to eq('us_equity')
      expect(asset.tradable).to be_truthy
    end
  end
end
