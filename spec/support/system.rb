# System specs drive the app in headless Chrome, so Stimulus controllers run against the real markup.
# Selenium Manager resolves the browser and the driver; a failed example leaves a screenshot in tmp/screenshots.
RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1000 ]
  end
end
