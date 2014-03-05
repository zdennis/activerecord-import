require "pathname"
require "active_record"
require "active_record/version"

module ActiveRecord::Import
  AdapterPath = "activerecord-import/active_record/adapters"

  def self.base_adapter(adapter)
    case adapter
    when 'mysqlspatial' then 'mysql'
    when 'mysql2spatial' then 'mysql2'
    when 'spatialite' then 'sqlite3'
    when 'postgis' then 'postgresql'
    else adapter
    end
  end

  # Loads the import functionality for a specific database adapter
  def self.require_adapter(adapter)
    require File.join(AdapterPath,"/abstract_adapter")
    begin
      require File.join(AdapterPath,"/#{base_adapter(adapter)}_adapter")
    rescue LoadError
      # fallback
    end
  end

  # Loads the import functionality for the passed in ActiveRecord connection
  def self.load_from_connection_pool(connection_pool)
    require_adapter connection_pool.spec.config[:adapter]
  end
end

require 'activerecord-import/import'
require 'activerecord-import/active_record/adapters/abstract_adapter'
require 'activerecord-import/synchronize'
require 'activerecord-import/value_sets_parser'
