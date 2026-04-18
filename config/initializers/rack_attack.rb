# frozen_string_literal: true

return unless Rails.env.production?

Rails.application.config.middleware.use Rack::Attack

Rack::Attack.cache.store = Rails.cache

Rack::Attack.throttle("req/ip", limit: 500, period: 5.minutes) do |req|
  req.ip
end

Rack::Attack.throttle("logins/ip", limit: 5, period: 1.minute) do |req|
  req.ip if req.path == "/users/sign_in" && req.post?
end

Rack::Attack.throttle("password_resets/email", limit: 3, period: 1.hour) do |req|
  next unless req.path == "/users/password" && req.post?

  email = req.params.dig("user", "email").to_s.downcase.strip
  email.presence
end

Rack::Attack.throttle("password_resets/ip", limit: 10, period: 1.hour) do |req|
  req.ip if req.path == "/users/password" && req.post?
end

Rack::Attack.throttle("registrations/ip", limit: 5, period: 1.hour) do |req|
  req.ip if req.path == "/users" && req.post?
end

ActiveSupport::Notifications.subscribe("throttle.rack_attack") do |_name, _start, _finish, _id, payload|
  req = payload[:request]
  Rails.logger.warn(
    "[rack-attack] throttled #{req.env["rack.attack.matched"]} " \
    "ip=#{req.ip} path=#{req.path} method=#{req.request_method}"
  )
end
