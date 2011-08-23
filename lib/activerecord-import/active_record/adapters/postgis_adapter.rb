require "active_record/connection_adapters/postgis_adapter"
require "activerecord-import/adapters/postgis_adapter"

class ActiveRecord::ConnectionAdapters::PostGISAdapter::MainAdapter
  include ActiveRecord::Import::PostGISAdapter::InstanceMethods
end

