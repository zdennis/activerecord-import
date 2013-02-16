class Widget < ActiveRecord::Base
  self.primary_key = :w_id

  default_scope lambda { where(active: true) }

  serialize :data, Hash
end