require "active_record/connection_adapters/mysql2_adapter"
require "activerecord-import/active_record/adapters/mysql_base"

class ActiveRecord::ConnectionAdapters::Mysql2Adapter
  include ActiveRecord::ConnectionAdapters::MysqlBase
end