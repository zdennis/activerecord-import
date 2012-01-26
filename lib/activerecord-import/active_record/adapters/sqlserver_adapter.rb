require "active_record/connection_adapters/sqlserver_adapter"
require "activerecord-import/adapters/sqlserver_adapter"

class ActiveRecord::ConnectionAdapters::SQLServerAdapter
  include ActiveRecord::Import::SQLServerAdapter
end