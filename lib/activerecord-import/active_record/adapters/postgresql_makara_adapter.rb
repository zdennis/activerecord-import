require "activerecord-import/adapters/postgresql_adapter"

class ActiveRecord::ConnectionAdapters::MakaraPostgreSQLAdapter
  include ActiveRecord::Import::PostgreSQLAdapter
end
