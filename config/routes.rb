Rails.application.routes.draw do
  get 'up' => 'rails/health#show', as: :rails_health_check
  get 'service-worker' => 'rails/pwa#service_worker', as: :pwa_service_worker
  get 'manifest' => 'rails/pwa#manifest', as: :pwa_manifest

  root 'home#show'

  get 'saved-people' => 'saved_people#show', as: :saved_people
  get 'saved-people/export' => 'saved_people#export', as: :export_saved_people
  post 'people/:slug/save' => 'saved_people#create', as: :save_person
  delete 'people/:slug/save' => 'saved_people#destroy', as: :remove_saved_person
  patch 'people/:slug/save-note' => 'saved_people#update', as: :update_saved_person_note

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
  resources :encounter_cases, path: 'cases', param: :slug
  resources :research_notes, only: :create
end
