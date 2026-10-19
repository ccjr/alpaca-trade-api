require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "standard/rake"

RSpec::Core::RakeTask.new(:spec)

task default: %i[spec standard openapi:coverage]

namespace :openapi do
  desc "Report OpenAPI operations not implemented by the gem (fails if any are missing)"
  task :coverage do
    require_relative "lib/alpaca"
    require_relative "lib/alpaca/openapi_coverage"
    abort "OpenAPI coverage incomplete" unless Alpaca::OpenAPICoverage.new.report
  end

  desc "Download the latest Alpaca OpenAPI specs into openapi/ (review with git diff)"
  task :update do
    require "json"
    require "net/http"
    require_relative "lib/alpaca/openapi_coverage"
    Alpaca::OpenAPICoverage::URLS.each do |api, url|
      body = Net::HTTP.get(URI(url))
      path = File.join("openapi", Alpaca::OpenAPICoverage::SPECS.fetch(api))
      File.write(path, JSON.pretty_generate(JSON.parse(body)) + "\n")
      puts "updated #{path}"
    end
  end
end

namespace :openapi do
  desc "Print a draft Alpaca::Model for an OpenAPI schema: rake 'openapi:model[broker,Journal,Journal]'"
  task :model, [:api, :schema, :class_name] do |_, args|
    require_relative "rakelib/model_generator"
    puts ModelGenerator.new(args[:api]).generate(args[:schema], args[:class_name] || args[:schema])
  end
end
