require "arjdbc/mysql/adapter"
require "activerecord-import/adapters/mysql_adapter"

class ActiveRecord::ConnectionAdapters::MysqlAdapter
  include ActiveRecord::Import::MysqlAdapter
end
