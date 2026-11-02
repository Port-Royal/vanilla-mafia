FactoryBot.define do
  factory :game_protocol_event do
    game
    sequence(:client_id) { |n| "client-#{n}" }
    sequence(:action_id) { |n| "action-#{n}" }
    sequence(:position)
    kind { "note" }
    phase { "day" }
    day_number { 1 }
    # A sanction must name the player it belongs to.
    target_seats { %w[foul tech].include?(kind) ? [ 1 ] : [] }
  end
end
