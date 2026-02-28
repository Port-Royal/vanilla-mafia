FactoryBot.define do
  factory :player_claim do
    user
    player
    status { "pending" }
  end
end
