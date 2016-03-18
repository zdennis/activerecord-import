class Topic < ActiveRecord::Base
  validates_presence_of :author_name
  validates :title, numericality: { only_integer: true }, on: :context_test

  has_many :books, inverse_of: :topic
  belongs_to :parent, class_name: "Topic"

  composed_of :description, mapping: [%w(title title), %w(author_name author_name)], allow_nil: true, class_name: "TopicDescription"
end
