# frozen_string_literal: true

require "active_record/connection_adapters/mysql2_proxy_adapter"
require "activerecord-import/adapters/mysql2_proxy_adapter"

ActiveSupport.on_load(:active_record_mysql2proxyadapter) do |klass|
  klass.include(ActiveRecord::Import::Mysql2ProxyAdapter)
end
