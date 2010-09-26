require "active_record/connection_adapters/mysql_adapter"
require "activerecord-import/adapters/mysql_adapter"

class ActiveRecord::ConnectionAdapters::MysqlAdapter
  include ActiveRecord::Extensions::Import::MysqlAdapter::InstanceMethods
end