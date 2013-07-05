class Book < ActiveRecord::Base
  belongs_to :topic, :inverse_of=>:books
end
