FactoryBot.define do
  factory :announcement do
    sequence(:version) { |n| "1.0.#{n}" }
    message_ru { "Доступна новая функция" }
    message_en { "New feature available" }
  end
end
