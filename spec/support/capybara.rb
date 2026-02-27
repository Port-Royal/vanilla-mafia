require "capybara/rspec"

module AdminSignInHelper
  def sign_in_as_admin(user)
    visit "/users/sign_in"
    fill_in I18n.t("activerecord.attributes.user.email"), with: user.email
    fill_in I18n.t("activerecord.attributes.user.password"), with: "password123"
    find("input[type='submit']").click
  end
end

RSpec.configure do |config|
  config.define_derived_metadata(file_path: %r{spec/acceptance/}) do |metadata|
    metadata[:type] = :feature
  end

  config.include AdminSignInHelper, type: :feature
end
