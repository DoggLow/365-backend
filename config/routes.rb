Rails.application.eager_load! if Rails.env.development?

class ActionDispatch::Routing::Mapper
  def draw(routes_name)
    instance_eval(File.read(Rails.root.join("config/routes/#{routes_name}.rb")))
  end
end

Exchange::Application.routes.draw do
  use_doorkeeper

  root 'welcome#index'

  if Rails.env.development?
    mount MailsViewer::Engine => '/mails'
  end

  get '/signin' => 'sessions#new', :as => :signin
  get '/signup' => 'identities#new', :as => :signup
  get '/signout' => 'sessions#destroy', :as => :signout
  get '/auth/failure' => 'sessions#failure', :as => :failure
  match '/auth/:provider/callback' => 'sessions#create', via: [:get, :post]
  post '/auth/app' => 'sessions#google_auth_verify', :as => :google_auth_verify

  resource :member, :only => [:show, :update]
  resource :identity, :only => [:edit, :update]

  get '/configs/currencies' => 'configs#currencies', as: :currency_list
  get '/configs/levels' => 'configs#levels', as: :level_list
  get '/configs/purchase' => 'configs#purchase', as: :level_purchase

  namespace :verify do
    resource :sms_auth,    only: [:show, :update]
    resource :google_auth, only: [:show, :update, :destroy]
  end

  namespace :authentications do
    resources :emails, only: [:new, :create]
    resources :identities, only: [:new, :create]
  end

  scope :constraints => { id: /[a-zA-Z0-9]{32}/ } do
    resources :reset_passwords
    resources :activations, only: [:new, :edit, :update]
  end

  get '/api' => 'documents#api_v2', :as => :api_doc
  get '/websocket_api' => 'documents#websocket_api', :as => :websocket_api_doc
  # get '/oauth' => 'documents#oauth', :as => :oauth

  resources :documents, only: [:show]
  resources :two_factors, only: [:show, :index, :update]

  scope ['', 'webhooks', ENV['WEBHOOKS_SECURE_URL_COMPONENT'].presence, ':ccy'].compact.join('/'), as: 'webhooks' do
    post '', to: 'webhooks#tx_created'
  end

  scope module: :private do
    resource  :id_document, only: [:edit, :update]

    resources :api_tokens

    resources :fund_sources, only: [:index, :create, :update, :destroy]

    resources :funds, only: [:withdraws, :deposits] do
      collection do
        get  :withdraws
        get  :deposits
      end
    end

    resources 'deposits/:currency', controller: 'deposits', as: 'deposit', only: %i[ destroy ]

    resources 'withdraws/:currency', controller: 'withdraws', as: 'withdraw', only: %i[ create destroy ]

    resources :account_versions, :only => :index
    resources :accounts, :only => :index

    resources :accounts, only: [:index, :main, :lending] do
      collection do
        get  :main
        get  :lending
      end
    end

    resources :move_funds, only: [:create]

    get '/history/orders' => 'history#orders', as: :order_history
    get '/history/trades' => 'history#trades', as: :trade_history
    get '/history/account' => 'history#account', as: :account_history
    get '/history/loans' => 'history#loans', as: :loan_history

    get '/markets' => 'markets#index', as: :market_list

    resources :markets, :only => :show, :constraints => MarketConstraint do
      resources :orders, :only => [:index, :destroy] do
        collection do
          post :clear
        end
      end
      resources :order_bids, :only => [:create] do
        collection do
          post :clear
        end
      end
      resources :order_asks, :only => [:create] do
        collection do
          post :clear
        end
      end
    end

    resources :margin_markets, :only => :show, :constraints => MarginMarketConstraint do
      resources :trigger_orders, :only => [:index, :destroy] do
        collection do
          post :clear
        end
      end
      resources :trigger_bids, :only => [:create] do
        collection do
          post :clear
        end
      end
      resources :trigger_asks, :only => [:create] do
        collection do
          post :clear
        end
      end
    end

    resources :positions, :only => [:update]
    resources :referrals, :only => [:index]
    get '/referrals/list' => 'referrals#list', as: :referral_list
    get '/referrals/purchase' => 'referrals#purchase', as: :purchase_referral

    resources :loan_markets, :only => [:show, :update] do
      resources :open_loans, :only => [:index, :create, :update, :destroy] do
        collection do
          post :clear
        end
      end
    end

    resources :tickets, only: [:index, :new, :create, :show, :destroy] do
      resources :comments, only: [:create]
    end

    resources :invests, only: [:index, :create]
    resources :point_exchanges, only: [:index, :create]

    resources :purchases, only: [:index, :create, :prepare, :options, :profits] do
      collection do
        post  :options
        post  :prepare
        get  :profits
      end
    end
  end

  draw :admin

  mount APIv2::Mount => APIv2::Mount::PREFIX

end
