FactoryBot.define do
  factory :game_protocol_event do
    game
    sequence(:client_id) { |n| "client-#{n}" }
    sequence(:action_id) { |n| "action-#{n}" }
    sequence(:position)
    kind { "note" }
    phase { "day" }
    day_number { 1 }
  end
end
