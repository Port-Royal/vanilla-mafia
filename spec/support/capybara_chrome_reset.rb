# Chrome 158 rejects the `origin: "*"` that Capybara 3.40's ChromeDriver#reset! passes to Storage.clearDataForOrigin
# ("invalid argument: * is not a valid URL"), so every system spec fails on session reset. This applies the fix from
# teamcapybara/capybara#2868 (issue #2865): remember the page's origin before navigating to about:blank, and when Chrome
# refuses "*" clear the cookies with Network.clearBrowserCookies and the local storage of that origin instead. Unlike
# "*", that leaves the local storage of other origins the example visited; this app runs on one host.
# Delete this file once a Capybara release includes the fix; until then a newer Capybara prints a warning to recheck.
require "capybara/selenium/driver"

module CapybaraChromeReset
  # Same steps as Capybara::Selenium::Driver::ChromeDriver#reset!, plus reading the origin before leaving the page.
  def reset!
    return unless @browser
    return super if chromedriver_version < 73

    switch_to_window(window_handles.first)
    window_handles.slice(1..).each { |win| close_window(win) }

    origin = nil
    timer = Capybara::Helpers.timer(expire_in: 10)
    begin
      # Read once: after an alert on leaving the page, the retry would already be on about:blank.
      origin ||= current_origin
      clear_storage unless uniform_storage_clear?
      @browser.navigate.to("about:blank")
      wait_for_empty_page(timer)
    rescue *unhandled_alert_errors
      accept_unhandled_reset_alert
      retry
    end

    clear_browser_data(origin)
  end

  private

  def clear_browser_data(origin)
    execute_cdp("Storage.clearDataForOrigin", origin: "*", storageTypes: storage_types_to_clear)
  rescue Selenium::WebDriver::Error::InvalidArgumentError
    execute_cdp("Network.clearBrowserCookies")
    return unless origin && clear_all_storage?

    execute_cdp("Storage.clearDataForOrigin", origin: origin, storageTypes: "local_storage")
  end

  def current_origin
    origin = Addressable::URI.parse(current_url).origin
    origin if origin.start_with?("http")
  end
end

# Applied on any version: a newer Capybara without the fix would otherwise break every system spec again, silently.
if Gem::Version.new(Capybara::VERSION) > Gem::Version.new("3.40.0")
  warn "spec/support/capybara_chrome_reset.rb: Capybara #{Capybara::VERSION} is newer than 3.40.0. " \
       "If it includes teamcapybara/capybara#2868, delete this file."
end
Capybara::Selenium::Driver::ChromeDriver.prepend(CapybaraChromeReset)
