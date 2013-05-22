require "em-synchrony"
require "em-synchrony/mysql2"
require "em-synchrony/activerecord"
require "activerecord-import/adapters/em_mysql2_adapter"

class ActiveRecord::ConnectionAdapters::EMMysql2Adapter
  include ActiveRecord::Import::EMMysql2Adapter
end
