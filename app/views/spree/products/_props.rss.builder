product.product_properties.each do |product_property|
  xml.tag!(product_property.property.name.downcase, product_property.value)
end
