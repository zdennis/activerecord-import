class Tag < ActiveRecord::Base
  self.primary_keys = :tag_id, :publisher_id
  has_many :books, inverse_of: :tag
end
