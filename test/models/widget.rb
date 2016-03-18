class Widget < ActiveRecord::Base
  self.primary_key = :w_id

  default_scope -> { where(active: true) }

  serialize :data, Hash
  serialize :json_data, JSON
end
