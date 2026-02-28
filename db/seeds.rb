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

# Feature toggles
toggle = FeatureToggle.find_or_initialize_by(key: "require_approval")
toggle.enabled = true
toggle.description = "Require admin approval for player claims"
toggle.save!

# Admin user (set ADMIN_EMAIL and ADMIN_PASSWORD env vars)
if ENV["ADMIN_EMAIL"].present? && ENV["ADMIN_PASSWORD"].present?
  user = User.find_or_initialize_by(email: ENV["ADMIN_EMAIL"])
  user.admin = true
  user.password = ENV["ADMIN_PASSWORD"] if user.new_record?
  user.save!
end
