# Roles dictionary
roles = {
  "peace" => "Мирный",
  "mafia" => "Мафия",
  "don" => "Дон",
  "sheriff" => "Шериф"
}

roles.each do |code, name|
  Role.find_or_create_by!(code: code) do |role|
    role.name = name
  end
end

# Admin user (set ADMIN_EMAIL and ADMIN_PASSWORD env vars)
if ENV["ADMIN_EMAIL"].present? && ENV["ADMIN_PASSWORD"].present?
  User.find_or_create_by!(email: ENV["ADMIN_EMAIL"]) do |user|
    user.password = ENV["ADMIN_PASSWORD"]
    user.admin = true
  end
end
