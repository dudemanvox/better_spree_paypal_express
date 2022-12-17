Spree::Core::Engine.add_routes do
  post '/paypal', :to => "paypal#express", :as => :paypal_express
  get '/paypal/confirm', :to => "paypal#confirm", :as => :confirm_paypal
  get '/paypal/cancel', :to => "paypal#cancel", :as => :cancel_paypal
  get '/paypal/notify', :to => "paypal#notify", :as => :notify_paypal
end