FactoryBot.define do
  factory :breakdown_speech do
    breakdown_phase
    speaker_seat { 1 }
    kind { "regular" }
    sequence(:position)

    trait :farewell do
      kind { "farewell" }
    end

    trait :justification do
      kind { "justification" }
      breakdown_vote_round { association :breakdown_vote_round, breakdown_phase: breakdown_phase, kind: "revote" }
    end
  end
end
