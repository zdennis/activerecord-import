# frozen_string_literal: true

class Author < ActiveRecord::Base
  if ENV['AR_VERSION'].to_f >= 7.1
    has_many :composite_books, query_constraints: [:id, :author_id], inverse_of: :author
  end
end
