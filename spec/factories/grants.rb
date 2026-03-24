FactoryBot.define do
  factory :grant do
    code { "user" }

    trait :admin do
      code { "admin" }
    end

    trait :judge do
      code { "judge" }
    end

    trait :editor do
      code { "editor" }
    end
  end
end
