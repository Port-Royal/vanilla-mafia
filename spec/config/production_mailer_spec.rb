require "rails_helper"

RSpec.describe "Production mailer configuration" do
  let(:config) { Rails.application.config_for(:production_mailer) }
  let(:production_config_path) { Rails.root.join("config/environments/production.rb") }
  let(:production_config) { File.read(production_config_path) }

  it "sets delivery_method to :smtp" do
    expect(production_config).to match(/config\.action_mailer\.delivery_method\s*=\s*:smtp/)
  end

  it "configures smtp_settings with Resend" do
    expect(production_config).to include('address: "smtp.resend.com"')
  end
end
