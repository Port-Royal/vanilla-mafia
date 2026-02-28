Rails.application.routes.draw do
  devise_for :users

  authenticate :user, ->(u) { u.admin? } do
    mount Avo::Engine => "/avo"
  end

  root "seasons#show", defaults: { number: 5 }

  resources :seasons, only: [ :show ], param: :number do
    resources :series, only: [ :show ], param: :number
  end

  resources :games, only: [ :show ]
  resources :players, only: [ :show ]
  resource :profile, only: [ :edit, :update ]

  get "hall", to: "hall_of_fame#show"

  match "/404", to: "errors#show", via: :all, defaults: { code: 404 }
  match "/422", to: "errors#show", via: :all, defaults: { code: 422 }
  match "/500", to: "errors#show", via: :all, defaults: { code: 500 }

  get "up" => "rails/health#show", as: :rails_health_check
end
