# frozen_string_literal: true

require "activerecord-import/adapters/trilogy_adapter"

class ActiveRecord::ConnectionAdapters::TrilogyAdapter
  include ActiveRecord::Import::TrilogyAdapter
end
