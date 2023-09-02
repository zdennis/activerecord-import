# frozen_string_literal: true

require "active_record/import/trilogy_adapter"

class ActiveRecord::ConnectionAdapters::TrilogyAdapter
  include ActiveRecord::Import::TrilogyAdapter
end
