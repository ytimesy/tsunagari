Rails.application.routes.draw do
  get 'up' => 'rails/health#show', as: :rails_health_check
  get 'service-worker' => 'rails/pwa#service_worker', as: :pwa_service_worker
  get 'manifest' => 'rails/pwa#manifest', as: :pwa_manifest

  root 'home#show'

  get 'login' => 'sessions#new'
  post 'login' => 'sessions#create'
  delete 'logout' => 'sessions#destroy'

  resources :people, param: :slug do
    collection do
      get :graph
      get :youtube_guide
    end
  end
  resources :person_imports, only: %i[new create]
  resources :list_requests, path: 'requests', only: %i[index new create]
  resources :encounter_cases, path: 'cases', param: :slug
  resources :research_notes, only: :create
end
