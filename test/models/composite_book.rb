# frozen_string_literal: true

class CompositeBook < ActiveRecord::Base
  self.primary_key = %i[id author_id]
  belongs_to :author
  if ENV['AR_VERSION'].to_f <= 7.0 || ENV['AR_VERSION'].to_f >= 8.0
    unless ENV["SKIP_COMPOSITE_PK"]
      has_many :composite_chapters, inverse_of: :composite_book,
                                    foreign_key: [:id, :author_id]
    end
  else
    has_many :composite_chapters, inverse_of: :composite_book,
                                  query_constraints: [:id, :author_id]
  end

  # PostgreSQL's sequence for the id column, which isn't found because of the composite primary key
  def self.sequence_name
    connection_pool.with_connection { |conn| conn.adapter_name =~ /postg/i } ? "composite_book_id_seq" : super
  end
end
