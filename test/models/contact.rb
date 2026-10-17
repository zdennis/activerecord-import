# frozen_string_literal: true

# display_name is a column, but also an alias of name.
class Contact < ActiveRecord::Base
  alias_attribute :display_name, :name
end
