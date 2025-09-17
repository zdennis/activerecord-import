# frozen_string_literal: true

require "activerecord-import/adapters/postgresql_adapter"
require "activerecord-import/adapters/active_record_proxy_adapter"

module ActiveRecord::Import::PostgreSQLProxyAdapter
  include ActiveRecord::Import::PostgreSQLAdapter
  include ActiveRecord::Import::ActiveRecordProxyAdapter
end
