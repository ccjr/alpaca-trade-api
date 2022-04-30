# frozen_string_literal: true

RSpec.describe Alpaca::Trade::Api do
  it 'has a version number' do
    expect(Alpaca::Trade::Api::VERSION).not_to be nil
  end

  describe '.configure' do
    let(:key_id) { 'KEY_ID' }
    let(:key_secret) { 'KEY_S3CRET' }

    after do
      Alpaca::Trade::Api.reset
    end

    it 'defaults to expected values' do
      expect(ENV).to receive(:[]).with('ALPACA_API_KEY_ID').and_return(key_id).twice
      expect(ENV).to receive(:[]).with('ALPACA_API_SECRET_KEY').and_return(key_secret).twice

      expect(Alpaca::Trade::Api.configuration.data_endpoint).to eq('https://data.alpaca.markets')
      expect(Alpaca::Trade::Api.configuration.endpoint).to eq('https://paper-api.alpaca.markets')
      expect(Alpaca::Trade::Api.configuration.key_id).to eq(key_id)
      expect(Alpaca::Trade::Api.configuration.key_secret).to eq(key_secret)
    end

    it 'lets user configure extra_keys' do
      Alpaca::Trade::Api.configure do |config|
        config.endpoint = 'https://live.alapca.markets'
        config.key_id = 'ANOTHER_KEY_ID'
        config.key_secret = 'ANOTHER_KEY_S3CRET'
      end

      expect(Alpaca::Trade::Api.configuration.endpoint).to eq('https://live.alapca.markets')
      expect(Alpaca::Trade::Api.configuration.key_id).to eq('ANOTHER_KEY_ID')
      expect(Alpaca::Trade::Api.configuration.key_secret).to eq('ANOTHER_KEY_S3CRET')
    end
  end
end
