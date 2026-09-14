FactoryBot.define do
  factory :breakdown_move do
    breakdown_speech
    sequence(:position)
    kind { "other" }
    actor_seat { 1 }
    text { "comment" }

    trait :in_vote_round do
      breakdown_speech { nil }
      breakdown_vote_round
    end

    trait :sheriff_reveal_table do
      kind { "sheriff_reveal_table" }
    end

    trait :sheriff_reveal_to_player do
      kind { "sheriff_reveal_to_player" }
      target_seat { 2 }
    end

    trait :check_claim do
      kind { "check_claim" }
      claimed_color { "red" }
      night_number { 1 }
    end

    trait :nomination do
      kind { "nomination" }
      target_seat { 2 }
    end

    trait :check_request do
      kind { "check_request" }
      target_seat { 2 }
    end

    trait :split_break do
      kind { "split_break" }
    end

    trait :protection do
      kind { "protection" }
      target_seat { 2 }
    end

    trait :best_move do
      kind { "best_move" }
      best_move_seats { [ 2, 3, 4 ] }
    end

    trait :removal do
      kind { "removal" }
      removal_reason { "fouls" }
    end
  end
end
