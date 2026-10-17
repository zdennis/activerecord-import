# frozen_string_literal: true

require "activerecord-import/adapters/sqlite3_adapter"
require "activerecord-import/adapters/active_record_proxy_adapter"

module ActiveRecord::Import::SQLite3ProxyAdapter
  include ActiveRecord::Import::SQLite3Adapter
  include ActiveRecord::Import::ActiveRecordProxyAdapter
end
