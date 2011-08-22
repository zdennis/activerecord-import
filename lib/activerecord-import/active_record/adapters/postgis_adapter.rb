require "active_record/connection_adapters/postgis_adapter"
require "activerecord-import/adapters/postgis_adapter"

class ActiveRecord::ConnectionAdapters::PostgisAdapter
  include ActiveRecord::Import::PostgisAdapter::InstanceMethods
end

