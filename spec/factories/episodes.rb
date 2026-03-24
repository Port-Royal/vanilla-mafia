FactoryBot.define do
  factory :episode do
    sequence(:title) { |n| "Episode #{n}" }
    status { "draft" }
  end
end
