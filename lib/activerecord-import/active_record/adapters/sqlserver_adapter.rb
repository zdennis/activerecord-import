if (RUBY_PLATFORM =~ /java/).nil?
  require "active_record/connection_adapters/sqlserver_adapter"
else
  require "active_record/connection_adapters/mssql_adapter"
end
require "activerecord-import/adapters/sqlserver_adapter"

if (RUBY_PLATFORM =~ /java/).nil?
  class ActiveRecord::ConnectionAdapters::SQLServerAdapter
    include ActiveRecord::Import::SQLServerAdapter
  end
else
  class ActiveRecord::ConnectionAdapters::MSSQLAdapter
    include ActiveRecord::Import::SQLServerAdapter
  end
end
