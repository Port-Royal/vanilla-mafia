FactoryBot.define do
  factory :playback_position do
    user
    episode
    position_seconds { 0 }
  end
end
