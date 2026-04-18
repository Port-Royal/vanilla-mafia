require "rails_helper"

RSpec.describe "Rack::Attack throttling", type: :request do
  before(:all) do
    @middleware_was_installed = Rails.application.middleware.include?(Rack::Attack)
    Rails.application.config.middleware.use(Rack::Attack) unless @middleware_was_installed

    @original_store = Rack::Attack.cache.store
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

    @original_throttles = Rack::Attack.throttles.dup
    Rack::Attack.throttles.clear
    RackAttackConfig.install_throttles!
  end

  after(:all) do
    Rack::Attack.cache.store = @original_store
    Rack::Attack.throttles.clear
    @original_throttles.each { |name, throttle| Rack::Attack.throttles[name] = throttle }
    Rails.application.config.middleware.delete(Rack::Attack) unless @middleware_was_installed
  end

  before { Rack::Attack.cache.store.clear }

  def ip_header(ip)
    { "REMOTE_ADDR" => ip }
  end

  describe "login throttle (5/min per IP)" do
    it "allows 5 login attempts then blocks the 6th" do
      5.times do
        post user_session_path, params: { user: { email: "x@example.com", password: "nope" } }, headers: ip_header("1.2.3.4")
        expect(response).not_to have_http_status(:too_many_requests)
      end

      post user_session_path, params: { user: { email: "x@example.com", password: "nope" } }, headers: ip_header("1.2.3.4")
      expect(response).to have_http_status(:too_many_requests)
    end

    it "isolates counters by IP" do
      5.times do
        post user_session_path, params: { user: { email: "x@example.com", password: "nope" } }, headers: ip_header("1.2.3.4")
      end

      post user_session_path, params: { user: { email: "x@example.com", password: "nope" } }, headers: ip_header("5.6.7.8")
      expect(response).not_to have_http_status(:too_many_requests)
    end
  end

  describe "password reset throttle (3/hour per email)" do
    it "blocks the 4th request for the same email across IPs" do
      3.times do |i|
        post user_password_path, params: { user: { email: "alice@example.com" } }, headers: ip_header("9.9.9.#{i}")
        expect(response).not_to have_http_status(:too_many_requests)
      end

      post user_password_path, params: { user: { email: "alice@example.com" } }, headers: ip_header("9.9.9.99")
      expect(response).to have_http_status(:too_many_requests)
    end

    it "normalizes email casing and whitespace" do
      3.times do
        post user_password_path, params: { user: { email: "Alice@example.com" } }, headers: ip_header("9.9.9.1")
      end

      post user_password_path, params: { user: { email: "  alice@EXAMPLE.com  " } }, headers: ip_header("9.9.9.2")
      expect(response).to have_http_status(:too_many_requests)
    end

    it "tracks different emails separately" do
      3.times do
        post user_password_path, params: { user: { email: "alice@example.com" } }, headers: ip_header("9.9.9.1")
      end

      post user_password_path, params: { user: { email: "bob@example.com" } }, headers: ip_header("9.9.9.1")
      expect(response).not_to have_http_status(:too_many_requests)
    end
  end

  describe "password reset per-IP throttle (10/hour)" do
    it "blocks the 11th request from the same IP even when emails rotate" do
      10.times do |i|
        post user_password_path, params: { user: { email: "user#{i}@example.com" } }, headers: ip_header("7.7.7.7")
        expect(response).not_to have_http_status(:too_many_requests)
      end

      post user_password_path, params: { user: { email: "user11@example.com" } }, headers: ip_header("7.7.7.7")
      expect(response).to have_http_status(:too_many_requests)
    end
  end

  describe "registration throttle (5/hour per IP)" do
    it "blocks the 6th registration attempt from the same IP" do
      5.times do |i|
        post user_registration_path, params: { user: { email: "new#{i}@example.com", password: "secret123", password_confirmation: "secret123" } }, headers: ip_header("3.3.3.3")
        expect(response).not_to have_http_status(:too_many_requests)
      end

      post user_registration_path, params: { user: { email: "new6@example.com", password: "secret123", password_confirmation: "secret123" } }, headers: ip_header("3.3.3.3")
      expect(response).to have_http_status(:too_many_requests)
    end
  end

  describe "global per-IP throttle (500 / 5 min)" do
    it "eventually blocks on sustained traffic from a single IP" do
      Rack::Attack.throttles.delete("req/ip")
      Rack::Attack.throttle("req/ip", limit: 3, period: 5.minutes) { |req| RackAttackConfig.client_ip(req) }

      3.times { get root_path, headers: ip_header("4.4.4.4") }
      get root_path, headers: ip_header("4.4.4.4")

      expect(response).to have_http_status(:too_many_requests)
    ensure
      Rack::Attack.throttles.delete("req/ip")
      Rack::Attack.throttle("req/ip", limit: 500, period: 5.minutes) { |req| RackAttackConfig.client_ip(req) }
    end
  end
end
