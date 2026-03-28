FactoryBot.define do
  factory :telegram_author do
    sequence(:telegram_user_id) { |n| 100_000 + n }
    user { nil }
  end
end
