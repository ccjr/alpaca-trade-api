
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "alpaca/trade/api/version"

Gem::Specification.new do |spec|
  spec.name          = "alpaca-trade-api"
  spec.version       = Alpaca::Trade::Api::VERSION
  spec.authors       = ["Cloves Carneiro Jr"]
  spec.email         = ["ccarneiroj@gmail.com"]

  spec.summary       = %q{Gem to interface with alpaca.markets.}
  spec.description   = %q{Alpaca API lets you build and trade with real-time market data for free.}
  spec.homepage      = "https://github.com/ccjr/alpaca-trade-api"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    # spec.metadata["allowed_push_host"] = "https://rubygems.org'"

    spec.metadata["homepage_uri"] = spec.homepage
    spec.metadata["source_code_uri"] = "https://github.com/ccjr/alpaca-trade-api"
    spec.metadata["changelog_uri"] = "https://github.com/ccjr/alpaca-trade-api/CHANGELOG.md"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "byebug"
  spec.add_development_dependency 'rb-readline'
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "simplecov", "~> 0.16"
  spec.add_development_dependency "vcr", "~> 6.0"
  spec.add_development_dependency "webmock", "~> 3.0"

  spec.add_dependency 'faraday', ">= 0.15", "< 2.0"
end
