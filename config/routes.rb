Rails.application.routes.draw do
  get 'up' => 'rails/health#show', as: :rails_health_check
  get 'service-worker' => 'rails/pwa#service_worker', as: :pwa_service_worker
  get 'manifest' => 'rails/pwa#manifest', as: :pwa_manifest

  root 'home#show'

  get 'login' => 'sessions#new'
  post 'login' => 'sessions#create'
  delete 'logout' => 'sessions#destroy'

  get 'insight-membership' => 'memberships#show', as: :insight_membership
  get 'join' => 'member_signups#new', as: :new_member_signup
  post 'join' => 'member_signups#create', as: :member_signups

  resources :people, param: :slug do
    collection do
      get :graph
      get :youtube_guide
    end
  end
  resources :person_imports, only: %i[new create]
  resources :research_notes, only: :create
end
