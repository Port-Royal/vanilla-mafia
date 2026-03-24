FactoryBot.define do
  factory :playlist_episode do
    playlist
    episode
    sequence(:position) { |n| n }
  end
end
