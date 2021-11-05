Spree::Core::Engine.add_routes do
  get 'products-cached.rss' => 'products#products_cached', :as => :products_cached
end
