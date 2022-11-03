module Spree
  module ProductsControllerDecorator
    def self.prepended(base)
      base.respond_to :rss, only: :index
    end

    def products_cached
      @refresh = params.delete(:refresh)
      @searcher = build_searcher(params.merge(include_images: true))
      @products = @searcher.retrieve_products
      @products = @products.includes(:possible_promotions) if @products.respond_to?(:includes)

      ProductFeedCreator.call(Rails.application.default_url_options, current_store, current_currency, @products, @refresh)
      feed_from_cache = Rails.cache.read(ProductFeedCreator::CACHED_KEY)

      respond_to do |format|
        format.rss { render xml: feed_from_cache }
      end
    end
  end
end

Spree::ProductsController.prepend Spree::ProductsControllerDecorator if defined?(Spree::ProductsController) && Spree::ProductsController.included_modules.exclude?(Spree::ProductsControllerDecorator)
