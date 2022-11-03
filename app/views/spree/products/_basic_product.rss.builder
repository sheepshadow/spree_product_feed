xml.tag!("g:id", current_store.id.to_s + "-" + product.id.to_s)

unless product.property("g:title").present?
  xml.tag!("g:title", product.name)
end
unless product.property("g:description").present?
  if product.respond_to?(:short_description) && product.short_description.present?
    xml.tag!("g:description", product.short_description)
  elsif product.description.present?
    xml.tag!("g:description", product.description)
  else
    xml.tag!("g:description", product.meta_description)
  end
end

xml.tag!("g:link", spree.product_url(product))
# xml.tag!("g:image_link", product.images.first.my_cf_image_url("large"))
xml.tag!("g:availability", product.in_stock? ? "in stock" : "out of stock")
if defined?(product.compare_at_price) && !product.compare_at_price.nil?
  if product.compare_at_price > product.price
    xml.tag!("g:price", product.compare_at_price.to_s + " " + current_currency)
    xml.tag!("g:sale_price", product.price_in(current_currency).amount.to_s + " " + current_currency)
  else
    xml.tag!("g:price", product.price_in(current_currency).amount.to_s + " " + current_currency)
  end
else
  xml.tag!("g:price", product.price_in(current_currency).amount.to_s + " " + current_currency)
end
xml.tag!("g:" + product.unique_identifier_type, product.unique_identifier)
xml.tag!("g:sku", product.sku)
# xml.tag!("g:product_type", google_product_type(product))

unless product.product_properties.blank?
  xml << render(partial: "props", locals: {product: product})
end
