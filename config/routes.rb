Rails.application.routes.draw do
  devise_for :users, controllers: { omniauth_callbacks: "users/omniauth_callbacks" }

  authenticate :user, ->(u) { u.can_manage_protocols? } do
    namespace :judge do
      resources :protocols, only: [ :index, :new, :create, :edit, :update ] do
        member do
          patch :autosave
        end
      end
    end
  end

  authenticate :user, ->(u) { u.can_manage_news? } do
    namespace :admin do
      resources :news, only: [ :index, :new, :create, :show, :edit, :update, :destroy ] do
        member do
          patch :publish
          patch :unpublish
        end
      end
    end
  end

  authenticate :user, ->(u) { u.admin? } do
    namespace :admin do
      resource :telegram_settings, only: [ :show ], path: "telegram"
      resources :telegram_authors, only: [ :create, :destroy ], path: "telegram/authors"
    end
  end

  authenticate :user, ->(u) { u.admin? } do
    mount Avo::Engine => "/avo"
  end

  root to: "home#index"

  resources :competitions, only: [ :show ], param: :slug

  get "seasons/:number", to: "legacy_redirects#season", as: :season
  get "seasons/:season_number/series/:number", to: "legacy_redirects#series", as: :season_series

  resources :news, only: [ :index ]
  get "news/:id", to: redirect("/news", status: 301)
  resources :games, only: [ :show ] do
    member do
      get :overlay
    end
  end
  resources :players, only: [ :show ] do
    resource :claim, only: [ :create ], controller: "player_claims"
    resource :dispute, only: [ :new, :create ], controller: "player_disputes"
  end
  resource :locale, only: [ :update ]
  resource :profile, only: [ :edit, :update ]
  resource :notification_settings, only: [ :edit, :update ]
  resources :announcement_dismissals, only: [ :create ], path: "announcements/dismiss"

  namespace :podcast do
    resources :episodes, only: [ :index, :show ] do
      resource :position, only: [ :update ], controller: "playback_positions"
    end
    resources :playlists, only: [ :index, :show ]
  end

  get "help", to: "help#index", as: :help_index
  get "help/:slug", to: "help#show", as: :help

  get "hall", to: "hall_of_fame#show"

  match "/404", to: "errors#show", via: :all, defaults: { code: 404 }
  match "/422", to: "errors#show", via: :all, defaults: { code: 422 }
  match "/500", to: "errors#show", via: :all, defaults: { code: 500 }

  namespace :webhooks do
    post "telegram", to: "telegram#create", as: :telegram
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
