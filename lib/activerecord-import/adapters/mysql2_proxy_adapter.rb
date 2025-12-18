# frozen_string_literal: true

require "activerecord-import/adapters/mysql2_adapter"
require "activerecord-import/adapters/active_record_proxy_adapter"

module ActiveRecord::Import::Mysql2ProxyAdapter
  include ActiveRecord::Import::Mysql2Adapter
  include ActiveRecord::Import::ActiveRecordProxyAdapter
end
