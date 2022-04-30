# frozen_string_literal: true

RSpec.describe Alpaca::Market::Client do
  describe '#crypto_bars' do
    let(:api_configuration) do
      instance_double(Alpaca::Trade::Api::Configuration, key_id: 'KEY_ID', key_secret: 'KEY_S3CRET')
    end

    before do
      allow(Alpaca::Trade::Api).to receive(:configuration).and_return(api_configuration)
    end

    it 'returns an array of Bar objects', :vcr do
      bars = subject.crypto_bars('SOLUSD', '1Min')
      expect(bars).to be_an(Array)
      expect(bars.first).to be_an(Alpaca::Market::Crypto::Bar)
    end
  end
end
