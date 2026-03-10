FactoryBot.define do
  factory :tagging do
    tag
    taggable factory: :news
  end
end
