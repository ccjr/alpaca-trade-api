RSpec.describe Alpaca::Trade::Api do
  it "has a version number" do
    expect(Alpaca::Trade::Api::VERSION).not_to be nil
  end

  describe '.configure' do
    let(:logger) { double(:logger) }

    it 'defaults to expected values' do
      expect(Alpaca::Trade::Api.configuration.endpoint).to eq('https://paper-api.alpaca.markets')
      expect(Alpaca::Trade::Api.configuration.key_id).to be_nil
      expect(Alpaca::Trade::Api.configuration.key_secret).to be_nil
    end

    it 'lets user configure extra_keys' do
      Alpaca::Trade::Api.configure do |config|
        config.endpoint = 'https://live.alapca.markets'
        config.key_id = 'key_id'
        config.key_secret = 'key_secret'
      end

      expect(Alpaca::Trade::Api.configuration.endpoint).to eq('https://live.alapca.markets')
      expect(Alpaca::Trade::Api.configuration.key_id).to eq('key_id')
      expect(Alpaca::Trade::Api.configuration.key_secret).to eq('key_secret')
    end
  end
end
