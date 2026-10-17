# frozen_string_literal: true

class Shipment < ActiveRecord::Base
  belongs_to :warehouse, inverse_of: :shipments, primary_key: :identifier
end
