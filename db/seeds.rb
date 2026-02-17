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

# Admin user
User.find_or_create_by!(email: "admin@vanilla-mafia.ru") do |user|
  user.password = "password"
  user.admin = true
end
