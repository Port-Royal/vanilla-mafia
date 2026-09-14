FactoryBot.define do
  factory :game_breakdown do
    sequence(:title) { |n| "Breakdown #{n}" }
    author factory: :user
  end
end
