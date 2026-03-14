FactoryBot.define do
  factory :telegram_author do
    sequence(:telegram_user_id) { |n| 100_000 + n }
    telegram_username { "user_#{telegram_user_id}" }
    user { nil }
  end
end
