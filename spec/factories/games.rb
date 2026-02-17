FactoryBot.define do
  factory :game do
    season { 1 }
    series { 1 }
    sequence(:game_number)
  end
end
