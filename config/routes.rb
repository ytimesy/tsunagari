Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  root "home#show"

  get "sign_in", to: "sessions#new"
  post "sign_in", to: "sessions#create"
  delete "sign_out", to: "sessions#destroy"

  get "sign_up", to: "registrations#new"
  post "sign_up", to: "registrations#create"

  resources :people, param: :slug
  resources :encounter_cases, path: "cases", param: :slug
  resources :research_notes, only: :create
end
