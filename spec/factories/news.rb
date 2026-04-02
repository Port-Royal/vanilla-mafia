FactoryBot.define do
  factory :news, class: "News" do
    sequence(:title) { |n| "News article #{n}" }
    author factory: :user

    trait :published do
      status { "published" }
      published_at { Time.current }
    end

    trait :with_game do
      game
    end

    trait :with_photo do
      after(:create) do |news|
        File.open(Rails.root.join("spec/fixtures/files/selfie.jpg"), "rb") do |file|
          news.photos.attach(
            io: file,
            filename: "photo.jpg",
            content_type: "image/jpeg"
          )
        end
      end
    end
  end
end
