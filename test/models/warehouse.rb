# frozen_string_literal: true

class Warehouse < ActiveRecord::Base
  has_many :shipments, inverse_of: :warehouse, primary_key: :identifier
end
