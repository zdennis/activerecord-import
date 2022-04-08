# frozen_string_literal: true

class Customer < ActiveRecord::Base
  has_many :orders,
    inverse_of: :customer,
    primary_key: %i(account_id id),
    foreign_key: %i(account_id customer_id)
end
