class Book < ActiveRecord::Base
  belongs_to :topic, inverse_of: :books
  has_many :chapters, inverse_of: :book
  has_many :end_notes, inverse_of: :book
  if ENV['AR_VERSION'].to_f >= 4.1
    enum status: [:draft, :published]
  end
end
