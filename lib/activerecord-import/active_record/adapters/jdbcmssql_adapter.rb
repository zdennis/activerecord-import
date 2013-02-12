require "arjdbc/mssql/adapter"
require "activerecord-import/adapters/sqlserver_adapter"

class ActiveRecord::ConnectionAdapters::MssqlJdbcConnection
  include ActiveRecord::Import::SQLServerAdapter
end