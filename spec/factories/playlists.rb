FactoryBot.define do
  factory :playlist do
    sequence(:title) { |n| "Playlist #{n}" }
  end
end
