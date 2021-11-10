require 'libxml'

class Renderer::Products
  def self.product_url(url_options, product)
    url = url_options[:host]
    url = url + ":" + url_options[:port].to_s if url_options[:port]
    url = url + "/products/" + product.slug
    url
  end

  def self.create_doc_xml(root, attributes=nil)
    doc = LibXML::XML::Document.new
    doc.encoding = LibXML::XML::Encoding::UTF_8
    doc.root = create_node(root, nil, attributes)
    doc
  end

  def self.create_node(name, value=nil, options=nil)
    node = LibXML::XML::Node.new(name)
    node.content = value.to_s unless value.nil?
    if options
      attributes = options.delete(:attributes)
      add_attributes(node, attributes) if attributes
    end
    node
  end

  def self.add_attributes(node, attributes)
    attributes.each do |name, value|
      LibXML::XML::Attr.new(node, name, value)
    end
  end

  def self.props(item, product)
    product.product_properties.each do |product_property|
      if product_property.property.presentation.downcase == "product_feed"
        item << create_node(product_property.property.name.downcase, product_property.value)
      end
    end
  end

  def self.basic_product(url_options, current_store, current_currency, item, product)
    item << create_node("g:id", current_store.id.to_s + "-" + product.id.to_s)

    unless product.property("g:title").present?
      item << create_node("g:title", product.name)
    end
    unless product.property("g:description").present?
      if product.short_description.present?
        item << create_node("g:description", product.short_description)
      elsif product.description.present?
        item << create_node("g:description", product.description)
      else
        item << create_node("g:description", product.meta_description)
      end
    end
    
    item << create_node("g:link", product_url(url_options, product))
    item << create_node("g:image_link", product.images.first.my_cf_image_url("large"))
    item << create_node("g:availability", product.in_stock? ? "in stock" : "out of stock")
    if defined?(product.compare_at_price) && !product.compare_at_price.nil?
      if product.compare_at_price > product.price
        item << create_node("g:price", product.compare_at_price.to_s + " " + current_currency)
        item << create_node("g:sale_price", product.price_in(current_currency).amount.to_s + " " + current_currency)
      else
        item << create_node("g:price", product.price_in(current_currency).amount.to_s + " " + current_currency)
      end
    else
      item << create_node("g:price", product.price_in(current_currency).amount.to_s + " " + current_currency)
    end
    item << create_node("g:" + product.unique_identifier_type, product.unique_identifier)
    item << create_node("g:sku", product.sku)
    item << create_node("g:product_type", google_product_type(product))
    
    unless product.product_properties.blank?
      props(item, product)
    end
  end

  def self.complex_product(url_options, current_store, current_currency, item, product, variant)
    item << create_node("g:id", (current_store.id.to_s + "-" + product.id.to_s + "-" + variant.id.to_s).downcase)

    unless product.property("g:title").present?
      item << create_node("g:title", product.name)
    end
    
    unless product.property("g:description").present?
      if product.short_description.present?
        item << create_node("g:description", product.short_description)
      elsif product.description.present?
        item << create_node("g:description", product.description)
      else
        item << create_node("g:description", product.meta_description)
      end
    end
    
    item << create_node("g:link", product_url(url_options, product) + "?variant=" + variant.id.to_s)
    item << create_node("g:image_link", product.variant_images.present? ? product.variant_images.first.my_cf_image_url("large") : product.images.first.my_cf_image_url("large"))
    item << create_node("g:availability", variant.in_stock? ? "in stock" : "out of stock")
    
    if defined?(variant.compare_at_price) && !variant.compare_at_price.nil?
      if variant.compare_at_price > product.price
        item << create_node("g:price", variant.compare_at_price.to_s + " " + current_currency)
        item << create_node("g:sale_price", variant.price_in(current_currency).amount.to_s + " " + current_currency)
      else
        item << create_node("g:price", variant.price_in(current_currency).amount.to_s + " " + current_currency)
      end
    else
      item << create_node("g:price", variant.price_in(current_currency).amount.to_s + " " + current_currency)
    end
    
    item << create_node("g:" + variant.unique_identifier_type, product.unique_identifier)
    item << create_node("g:sku", variant.sku)
    item << create_node("g:item_group_id", (current_store.id.to_s + "-" + product.id.to_s).downcase)
    item << create_node("g:product_type", google_product_type(product))
    
    options_xml_hash = Spree::Variants::XmlFeedOptionsPresenter.new(variant).xml_options
    options_xml_hash.each_with_index do |ops, index|
      if ops.option_type[:name] == "color"
        item << create_node("g:" + ops.option_type.presentation.downcase.parameterize(separator: '_'), ops.name)
        item << create_node("g:custom_label_" + index.to_s, ops.name) unless index > 4
      else
        item << create_node("g:" + ops.option_type.presentation.downcase.parameterize(separator: '_'), ops.presentation)
        item << create_node("g:custom_label_" + index.to_s, ops.presentation) unless index > 4
      end
    end
    
    unless product.product_properties.blank?
      props(item, product)
    end    
  end

  def self.xml(url_options, current_store, current_currency, products)
    doc = create_doc_xml("rss", { :attributes => { "xmlns:g" => "http://base.google.com/ns/1.0", "version" => "2.0" } })
    doc.root << (channel = create_node("channel"))

    channel << create_node("title", current_store.name)
    channel << create_node("link", current_store.url)
    channel << create_node("description", "Find out about new products first! Always be in the know when new products become available")
    
    if defined?(current_store.default_locale) && !current_store.default_locale.nil?
      channel << create_node("language", current_store.default_locale.downcase)
    else
      channel << create_node("language", "en-us")
    end

    products = products.except(:limit, :offset)
    products.each do |product|
      if product.feed_active?
        if product.variants_and_option_values(current_currency).any?
          product.variants.each do |variant|
            if variant.show_in_product_feed?
              channel << (item = create_node("item"))
              complex_product(url_options, current_store, current_currency, item, product, variant)
            end
          end
        else
          channel << (item = create_node("item"))
          basic_product(url_options, current_store, current_currency, item, product)
        end
      end
    end

    doc.to_s
  end
end