FactoryBot.define do
  factory :breakdown_night_action do
    breakdown_phase { association :breakdown_phase, :night }
    kind { "mafia_shot" }
    actor_seat { 1 }
    target_seat { 2 }
  end
end
