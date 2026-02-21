require "capybara/rspec"

module AdminSignInHelper
  def sign_in_as_admin(user)
    visit "/users/sign_in"
    fill_in "Email", with: user.email
    fill_in "Password", with: "password123"
    click_on "Log in"
  end
end

RSpec.configure do |config|
  config.define_derived_metadata(file_path: %r{spec/acceptance/}) do |metadata|
    metadata[:type] = :feature
  end

  config.include AdminSignInHelper, type: :feature
end
