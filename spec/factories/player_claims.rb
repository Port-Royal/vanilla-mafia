FactoryBot.define do
  factory :player_claim do
    user
    player
    status { "pending" }

    trait :dispute do
      dispute { true }
      evidence { "This is my profile." }
    end
  end
end
