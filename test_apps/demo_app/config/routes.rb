Rails.application.routes.draw do
  # Auth
  get  "login",  to: "sessions#new",     as: :login
  post "login",  to: "sessions#create"
  delete "logout", to: "sessions#destroy", as: :logout

  # Resources
  resources :products
  resources :articles
  resources :reports

  # MCP Chat
  resources :mcp_chats, only: [:create] do
    collection { delete :clear }
  end

  # Root
  root "products#index"
end
