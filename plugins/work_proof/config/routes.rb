Rails.application.routes.draw do
  resources :projects do
    resources :work_proofs, only: [:index]
  end
end
  