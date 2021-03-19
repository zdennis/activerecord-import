class Chapter < ActiveRecord::Base
  belongs_to :book, inverse_of: :chapters
  validates :title, presence: true
  validates :book_id, presence: true
end
