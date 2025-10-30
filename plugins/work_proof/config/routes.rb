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
    get 'work_proofs.:format', to: 'work_proofs_api#index', as: :api_project_work_proofs
    post 'work_proofs.:format', to: 'work_proofs_api#create'
    get 'work_proofs/:id.:format', to: 'work_proofs_api#show'
    put 'work_proofs/:id.:format', to: 'work_proofs_api#update'
    patch 'work_proofs/:id.:format', to: 'work_proofs_api#update'
    delete 'work_proofs/:id.:format', to: 'work_proofs_api#destroy'
    
    # Time tracking endpoints
    post 'work_proofs/:id/clock_out.:format', to: 'work_proofs_api#clock_out'
    post 'work_proofs/:id/consolidate.:format', to: 'work_proofs_api#consolidate'
    post 'work_proofs/consolidate_by_issue.:format', to: 'work_proofs_api#consolidate_by_issue'
  end
end
  