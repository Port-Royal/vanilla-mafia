FactoryBot.define do
  factory :game do
    season { 1 }
    series { 1 }
    sequence(:game_number)
    competition { association :competition, :series }
  end
end
