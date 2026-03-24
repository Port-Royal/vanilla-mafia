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

# Validate all feature toggles are seeded
missing_keys = FeatureToggle::KEYS - FeatureToggle.pluck(:key)
raise "Missing feature toggle seeds: #{missing_keys.join(', ')}" if missing_keys.any?

# Admin user (set ADMIN_EMAIL and ADMIN_PASSWORD env vars)
if ENV["ADMIN_EMAIL"].present? && ENV["ADMIN_PASSWORD"].present?
  user = User.find_or_initialize_by(email: ENV["ADMIN_EMAIL"])
  user.role = "admin"
  user.password = ENV["ADMIN_PASSWORD"] if user.new_record?
  user.save!

  admin_grant = Grant.find_or_create_by!(code: "admin")
  UserGrant.find_or_create_by!(user: user, grant: admin_grant)
end
