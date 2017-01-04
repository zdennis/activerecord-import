class CartItem < ActiveRecord::Base
  belongs_to :book, inverse_of: :cart_items
end
