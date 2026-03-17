FactoryBot.define do
  factory :competition do
    sequence(:name) { |n| "Competition #{n}" }
    kind { "season" }

    trait :season do
      kind { "season" }
      sequence(:legacy_season)
    end

    trait :series do
      kind { "series" }
      sequence(:legacy_season)
      sequence(:legacy_series)
    end

    trait :minicup do
      kind { "minicup" }
    end

    trait :tournament do
      kind { "tournament" }
    end

    trait :round do
      kind { "round" }
    end

    trait :group do
      kind { "group" }
    end

    trait :fun_session do
      kind { "fun_session" }
    end

    trait :featured do
      featured { true }
    end

    trait :with_parent do
      parent factory: :competition
    end
  end
end
