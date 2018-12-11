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

  resource :member, :only => [:edit, :update]
  resource :identity, :only => [:edit, :update]

  namespace :verify do
    resource :sms_auth,    only: [:show, :update]
    resource :google_auth, only: [:show, :update, :edit, :destroy]
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
  get '/oauth' => 'documents#oauth', :as => :oauth
  get '/fees' => 'documents#fees', :as => :fees
  get '/about' => 'documents#about', :as => :about
  get '/privacy-policy' => 'documents#privacy', :as => :privacy
  get '/terms-of-use' => 'documents#terms', :as => :terms
  get '/affiliate-program' => 'documents#affiliate', :as => :about_affiliate

  resources :documents, only: [:show]
  resources :two_factors, only: [:show, :index, :update]

  scope ['', 'webhooks', ENV['WEBHOOKS_SECURE_URL_COMPONENT'].presence, ':ccy'].compact.join('/'), as: 'webhooks' do
    post '', to: 'webhooks#tx_created'
  end

  scope module: :private do
    resource  :id_document, only: [:edit, :update]

    resources :settings, only: [:index]
    resources :api_tokens do
      member do
        delete :unbind
      end
    end

    resources :fund_sources, only: [:create, :update, :destroy]

    resources :funds, only: [:index] do
      collection do
        post :gen_address
      end
    end

    namespace :deposits do
      Deposit.descendants.each do |d|
        resources d.resource_name do
          collection do
            post :gen_address
          end
        end
      end
    end

    namespace :withdraws do
      Withdraw.descendants.each do |w|
        resources w.resource_name
      end
    end

    resources :account_versions, :only => :index

    resources :exchange_assets, :controller => 'assets'

    get '/affiliates' => 'affiliates#index', as: :affiliates
    post '/affiliates/new', to: 'affiliates#gen_affiliate_code', as: :new_affiliate

    resources :transfer_balances, only: [:index]

    get '/history/orders' => 'history#orders', as: :order_history
    get '/history/trades' => 'history#trades', as: :trade_history
    get '/history/account' => 'history#account', as: :account_history
    get '/history/loans' => 'history#loans', as: :loan_history

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

    resources :loan_markets, :only => [:show, :update] do
      resources :open_loans, :only => [:index, :create, :update, :destroy] do
        collection do
          post :clear
        end
      end
    end

    post '/pusher/auth', to: 'pusher#auth'

    resources :tickets, only: [:index, :new, :create, :show] do
      member do
        patch :close
      end
      resources :comments, only: [:create]
    end
  end

  draw :admin

  mount APIv2::Mount => APIv2::Mount::PREFIX

end
