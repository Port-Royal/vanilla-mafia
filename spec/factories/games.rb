FactoryBot.define do
  factory :game do
    sequence(:game_number)
    competition { association :competition, :series }
  end
end
