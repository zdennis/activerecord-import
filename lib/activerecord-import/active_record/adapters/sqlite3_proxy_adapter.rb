# frozen_string_literal: true

require "active_record/connection_adapters/sqlite3_proxy_adapter"
require "activerecord-import/adapters/sqlite3_proxy_adapter"

ActiveSupport.on_load(:active_record_sqlite3proxyadapter) do |klass|
  klass.include(ActiveRecord::Import::SQLite3ProxyAdapter)
end
