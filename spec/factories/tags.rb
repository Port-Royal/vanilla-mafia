FactoryBot.define do
  factory :tag do
    sequence(:name) { |n| "tag-#{n}" }
    sequence(:slug) { |n| "tag-#{n}" }
  end
end
