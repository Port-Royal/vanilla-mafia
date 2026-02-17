FactoryBot.define do
  factory :role do
    sequence(:code) { |n| "role_#{n}" }
    sequence(:name) { |n| "Role #{n}" }
  end
end
