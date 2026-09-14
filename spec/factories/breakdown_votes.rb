FactoryBot.define do
  factory :breakdown_vote do
    breakdown_vote_round
    sequence(:voter_seat) { |n| (n % 10) + 1 }
    candidate_seat { 1 }

    trait :lift do
      breakdown_vote_round { association :breakdown_vote_round, kind: "lift" }
      candidate_seat { nil }
      for_lift { true }
    end
  end
end
