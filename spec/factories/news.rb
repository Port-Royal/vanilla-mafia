FactoryBot.define do
  factory :news, class: "News" do
    sequence(:title) { |n| "News article #{n}" }
    author factory: :user

    trait :published do
      status { "published" }
      published_at { Time.current }
    end

    trait :with_game do
      game
    end
  end
end
