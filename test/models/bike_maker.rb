module Bike
  def self.table_name_prefix
    'bike_'
  end
  class Maker < ActiveRecord::Base
  end
end
