require "rails_helper"

# Without RAILS_ENV=test mutant boots Rails in development and runs every kill fork against the
# development database, which fakes neutral failures and kills (vm-uuz).
RSpec.describe "config/mutant.yml" do
  let(:config) { YAML.load_file(Rails.root.join("config/mutant.yml")) }

  it "boots Rails in the test environment" do
    expect(config.dig("environment_variables", "RAILS_ENV")).to eq("test")
  end
end
