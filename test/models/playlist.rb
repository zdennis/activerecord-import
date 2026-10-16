# frozen_string_literal: true

class Playlist < ActiveRecord::Base
  has_many :songs, inverse_of: :playlist
end
