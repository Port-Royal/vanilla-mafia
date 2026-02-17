FactoryBot.define do
  factory :rating do
    game
    player
    plus { 0 }
    minus { 0 }
    win { false }
  end
end
