FactoryBot.define do
  factory :award do
    sequence(:title) { |n| "Award #{n}" }
    staff { false }
  end
end
