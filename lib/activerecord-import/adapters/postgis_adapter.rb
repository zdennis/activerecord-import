require "activerecord-import/adapters/postgresql_adapter"

# The Postgis Adapter is a functionality superset
# of the PostgreSQLAdapter.
#
# see: https://github.com/dazuma/activerecord-postgis-adapter
module ActiveRecord::Import::PostGISAdapter
  include ActiveRecord::Import::PostgreSQLAdapter
end
