Rails.application.routes.draw do
  devise_for :users

  root "seasons#show", defaults: { number: 5 }

  resources :seasons, only: [ :show ], param: :number do
    resources :series, only: [ :show ], param: :number
  end

  resources :games, only: [ :show ]
  resources :players, only: [ :show ]

  get "hall", to: "hall_of_fame#show"

  get "up" => "rails/health#show", as: :rails_health_check
end
