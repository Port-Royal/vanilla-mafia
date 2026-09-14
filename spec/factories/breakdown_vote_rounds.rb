FactoryBot.define do
  factory :breakdown_vote_round do
    breakdown_phase
    sequence(:number)
    kind { "main" }
  end
end
