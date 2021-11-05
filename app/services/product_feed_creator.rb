class ProductFeedCreator < ApplicationService
  CACHED_KEY = "#{ENV['PRODUCT_FEED_CACHED_KEY']}"

  def initialize(url_options, current_store, current_currency, products, refresh)
    @url_options = url_options
    @current_store = current_store
    @current_currency = current_currency
    @products = products
    @refresh = refresh
  end

  def call()
    if @refresh
      Rails.cache.write(
        CACHED_KEY, 
        Renderer::Products.xml(@url_options, @current_store, @current_currency, @products),
        expires_in: 24.hours
      )
    else
      Rails.cache.fetch(CACHED_KEY, expires_in: 24.hours) do
        Renderer::Products.xml(@url_options, @current_store, @current_currency, @products)
      end
    end
  end
end