namespace :admin do
  get '/', to: 'dashboard#index', as: :dashboard

  resources :documents
  resources :id_documents,     only: [:index, :show, :update]
  resources :settings
  resources :markets, only: [:index]
  resources :tickets, only: [:index, :show] do
    member do
      patch :close
    end
    resources :comments, only: [:create]
  end

  resources :members, only: [:index, :show] do
    member do
      post :active
      post :toggle
    end

    resources :two_factors, only: [:destroy]
  end

  resources :referrals, only: [:index, :show]
  get 'referrals/:id/:type', to: 'referrals#tree'

  namespace :assets do
    resources :proofs
    resources :accounts
  end

  resources 'deposits/:currency', controller: 'deposits', as: 'deposit', :only => [:index, :update]
  resources 'withdraws/:currency', controller: 'withdraws', as: 'withdraw'

  namespace :lending do
    resources :loans, :only => [:index, :destroy]
    resource :history, :controller => 'history', :only => :show
  end

  namespace :tsf_pld do
    resources :purchase_options
    resources :products
    resources :purchases, only: [:index]
    resources :invests, only: [:index]
    resources :point_exchanges
  end

  namespace :statistic do
    resource :members, :only => :show
    resource :orders, :only => :show
    resource :trades, :only => :show
    resource :deposits, :only => :show
    resource :withdraws, :only => :show
  end
end
