FactoryBot.define do
  factory :game_participation do
    game
    player
    role
    plus { 0 }
    minus { 0 }
    win { false }
  end
end
