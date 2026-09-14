FactoryBot.define do
  factory :breakdown_phase do
    game_breakdown
    sequence(:position) { |n| n * 2 }

    trait :night do
      sequence(:position) { |n| (n * 2) - 1 }
    end
  end
end
