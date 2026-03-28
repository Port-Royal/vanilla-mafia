# Roles dictionary
roles = {
  "peace" => "Мирный",
  "mafia" => "Мафия",
  "don" => "Дон",
  "sheriff" => "Шериф"
}

roles.each do |code, name|
  role = Role.find_or_initialize_by(code: code)
  role.name = name
  role.save!
end

# Grants (user permission grants)
Grant::CODES.each do |code|
  Grant.find_or_create_by!(code: code)
end

# Feature toggles
toggle = FeatureToggle.find_or_initialize_by(key: "require_approval")
if toggle.new_record?
  toggle.enabled = true
  toggle.description = "Require admin approval for player claims"
end
toggle.save!

[
  { key: "home_hero", description: "Show hero section on main page" },
  { key: "home_running_tournaments", description: "Show running tournaments on main page" },
  { key: "home_recently_finished", description: "Show recently finished tournaments on main page" },
  { key: "home_recent_games", description: "Show recent games on main page" },
  { key: "home_latest_news", description: "Show latest news on main page" },
  { key: "home_hall_of_fame", description: "Show hall of fame teaser on main page" },
  { key: "home_stats", description: "Show stats block on main page" },
  { key: "home_documents", description: "Show documents section on main page" },
  { key: "home_whats_new", description: "Show What's New block on main page" },
  { key: "toast_whats_new", description: "Show What's New toast notification" }
].each do |attrs|
  block_toggle = FeatureToggle.find_or_initialize_by(key: attrs[:key])
  if block_toggle.new_record?
    block_toggle.enabled = true
    block_toggle.description = attrs[:description]
  end
  block_toggle.save!
end

# Validate all feature toggles are seeded
missing_keys = FeatureToggle::KEYS - FeatureToggle.pluck(:key)
raise "Missing feature toggle seeds: #{missing_keys.join(', ')}" if missing_keys.any?

# Admin user (set ADMIN_EMAIL and ADMIN_PASSWORD env vars)
if ENV["ADMIN_EMAIL"].present? && ENV["ADMIN_PASSWORD"].present?
  user = User.find_or_initialize_by(email: ENV["ADMIN_EMAIL"])
  user.password = ENV["ADMIN_PASSWORD"] if user.new_record?
  user.save!

  admin_grant = Grant.find_or_create_by!(code: "admin")
  UserGrant.find_or_create_by!(user: user, grant: admin_grant)
end
