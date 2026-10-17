# frozen_string_literal: true

class Song < ActiveRecord::Base
  belongs_to :playlist, inverse_of: :songs
  validates :title, uniqueness: true
end
