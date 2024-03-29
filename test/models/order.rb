# frozen_string_literal: true

class Order < ActiveRecord::Base
  unless ENV["SKIP_COMPOSITE_PK"]
    belongs_to :customer,
      inverse_of: :orders,
      primary_key: %i(account_id id),
      foreign_key: %i(account_id customer_id)
  end
end
