# frozen_string_literal: true

require "active_record/connection_adapters/postgresql_proxy_adapter"
require "activerecord-import/adapters/postgresql_proxy_adapter"

ActiveSupport.on_load(:active_record_postgresqlproxyadapter) do |klass|
  klass.include(ActiveRecord::Import::PostgreSQLProxyAdapter)
end
