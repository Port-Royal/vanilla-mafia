require "capybara/rspec"

RSpec.configure do |config|
  config.define_derived_metadata(file_path: %r{spec/acceptance/}) do |metadata|
    metadata[:type] = :feature
  end
end
