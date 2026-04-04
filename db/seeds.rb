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
  { key: "toast_whats_new", description: "Show What's New toast notification" },
  { key: "news_classic_pagination", description: "Use classic pagination on news page" },
  { key: "news_infinite_scroll", description: "Use infinite scroll on news page" },
  { key: "news_per_page", description: "Number of news articles per page", enabled: false },
  { key: "news_max_article_length", description: "Max article length (chars) on news index before truncation", enabled: false },
  { key: "news_score_keywords", description: "Comma-separated keywords for news scoring (e.g. игра,сезон,турнир)", enabled: true, value: "игра,сезон,турнир,рейтинг,мафия" }
].each do |attrs|
  block_toggle = FeatureToggle.find_or_initialize_by(key: attrs[:key])
  if block_toggle.new_record?
    block_toggle.enabled = attrs.fetch(:enabled, true)
    block_toggle.description = attrs[:description]
    block_toggle.value = attrs[:value] if attrs.key?(:value)
  end
  block_toggle.save!
end

# Validate all feature toggles are seeded
missing_keys = FeatureToggle::KEYS - FeatureToggle.pluck(:key)
raise "Missing feature toggle seeds: #{missing_keys.join(', ')}" if missing_keys.any?

# Sample announcements
[
  { version: "1.0.0", grant_code: nil, message_ru: "Добро пожаловать на обновлённый сайт Vanilla Mafia!", message_en: "Welcome to the updated Vanilla Mafia website!" },
  { version: "1.0.0", grant_code: nil, message_ru: "Теперь доступен Зал славы и архив игр.", message_en: "Hall of Fame and game archive are now available." },
  { version: "1.1.0", grant_code: "judge", message_ru: "Судьи: добавлены протоколы игр с автосохранением.", message_en: "Judges: game protocols with autosave added." },
  { version: "1.1.0", grant_code: "editor", message_ru: "Редакторы: добавлено управление новостями.", message_en: "Editors: news management added." },
  { version: "1.2.0", grant_code: nil, message_ru: "Добавлена лента новостей клуба.", message_en: "Club news feed added." },
  { version: "0.29.0", grant_code: "subscriber", message_ru: "Подписчики: добавлен подкаст с RSS-лентой, личным токеном и автоматическим определением длительности эпизодов.", message_en: "Subscribers: podcast added with RSS feed, personal token, and automatic episode duration detection." },
  { version: "0.29.0", grant_code: "judge", message_ru: "Судьи: в боковом меню добавлена ссылка на раздел справки.", message_en: "Judges: help section link added to the sidebar." },
  { version: "0.29.0", grant_code: "admin", message_ru: "Администраторы: в боковом меню добавлена ссылка на раздел справки.", message_en: "Admins: help section link added to the sidebar." },
  { version: "0.29.0", grant_code: nil, message_ru: "Улучшена валидация контента новостей.", message_en: "Improved news content validation." }
].each do |attrs|
  Announcement.find_or_create_by!(attrs)
end

# Admin user (set ADMIN_EMAIL and ADMIN_PASSWORD env vars)
if ENV["ADMIN_EMAIL"].present? && ENV["ADMIN_PASSWORD"].present?
  user = User.find_or_initialize_by(email: ENV["ADMIN_EMAIL"])
  user.password = ENV["ADMIN_PASSWORD"] if user.new_record?
  user.save!

  admin_grant = Grant.find_or_create_by!(code: "admin")
  UserGrant.find_or_create_by!(user: user, grant: admin_grant)
end
