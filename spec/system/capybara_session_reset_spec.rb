require "rails_helper"

# Capybara resets the browser between examples; a cookie or a localStorage key set in one example must not leak into
# the next. Guards the Chrome 158 workaround in spec/support/capybara_chrome_reset.rb.
RSpec.describe "Capybara session reset" do
  let(:wildcard_clear) { [ "Storage.clearDataForOrigin", { origin: "*", storageTypes: "cookies,local_storage" } ] }
  let(:cookies) { page.evaluate_script("document.cookie") }
  let(:stored_value) { page.evaluate_script("window.localStorage.getItem('reset_probe')") }

  before do
    visit root_path
    page.execute_script("document.cookie = 'reset_probe=1; path=/'; window.localStorage.setItem('reset_probe', '1')")
  end

  context "with the installed Chrome" do
    before do
      Capybara.reset_sessions!
      visit root_path
    end

    it "clears the cookies" do
      expect(cookies).not_to include("reset_probe")
    end

    it "clears the local storage of the page's origin" do
      expect(stored_value).to be_nil
    end
  end

  context "when Chrome rejects the wildcard origin" do
    before do
      allow(page.driver).to receive(:execute_cdp).and_call_original
      allow(page.driver).to receive(:execute_cdp).with(*wildcard_clear)
        .and_raise(Selenium::WebDriver::Error::InvalidArgumentError, "invalid argument: * is not a valid URL")
      Capybara.reset_sessions!
      visit root_path
    end

    it "clears the cookies" do
      expect(cookies).not_to include("reset_probe")
    end

    it "clears the local storage of the page's origin" do
      expect(stored_value).to be_nil
    end
  end

  context "when Chrome accepts the wildcard origin" do
    before do
      allow(page.driver).to receive(:execute_cdp).and_call_original
      allow(page.driver).to receive(:execute_cdp).with(*wildcard_clear).and_return({})
      Capybara.reset_sessions!
    end

    it "clears the browser data with the wildcard origin" do
      expect(page.driver).to have_received(:execute_cdp).with(*wildcard_clear).once
    end

    it "sends no other CDP command" do
      expect(page.driver).to have_received(:execute_cdp).once
    end
  end
end
