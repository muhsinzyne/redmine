Rails.application.routes.draw do
  resources :projects do
    # Web interface
    resources :work_proofs, only: [:index]
    
    # API endpoints
    namespace :api do
      resources :work_proofs, controller: 'work_proofs_api', except: [:new, :edit]
    end
  end
  
  # Alternative API routes (Redmine standard format)
  scope '/projects/:project_id' do
    # Work Proofs API (with screenshots)
    get 'work_proofs.:format', to: 'work_proofs_api#index', as: :api_project_work_proofs
    post 'work_proofs.:format', to: 'work_proofs_api#create'
    get 'work_proofs/:id.:format', to: 'work_proofs_api#show'
    put 'work_proofs/:id.:format', to: 'work_proofs_api#update'
    patch 'work_proofs/:id.:format', to: 'work_proofs_api#update'
    delete 'work_proofs/:id.:format', to: 'work_proofs_api#destroy'
    post 'work_proofs/consolidate_by_issue.:format', to: 'work_proofs_api#consolidate_by_issue'
    
    # Time Clockings API (without screenshots - for premium users)
    get 'time_clockings.:format', to: 'time_clockings_api#index', as: :api_project_time_clockings
    post 'time_clockings.:format', to: 'time_clockings_api#create'
    get 'time_clockings/:id.:format', to: 'time_clockings_api#show'
    put 'time_clockings/:id.:format', to: 'time_clockings_api#update'
    patch 'time_clockings/:id.:format', to: 'time_clockings_api#update'
    delete 'time_clockings/:id.:format', to: 'time_clockings_api#destroy'
    post 'time_clockings/consolidate_by_issue.:format', to: 'time_clockings_api#consolidate_by_issue'
  end
end
  