# frozen_string_literal: true

require "active_record/connection_adapters/trilogy_adapter"
require "activerecord-import/adapters/mysql2_adapter"

class ActiveRecord::ConnectionAdapters::TrilogyAdapter
  include ActiveRecord::Import::Mysql2Adapter
end
