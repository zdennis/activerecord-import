# frozen_string_literal: true

require_relative 'book'

class Dictionary < Book
  if ENV['AR_VERSION'].to_f >= 8.0
    enum :cover, [:hardcover, :paperback]
  else
    enum cover: [:hardcover, :paperback]
  end
end
