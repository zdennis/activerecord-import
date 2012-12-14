require "pathname"
require "active_record"
require "active_record/version"

module ActiveRecord::Import
  AdapterPath = File.join File.expand_path(File.dirname(__FILE__)), "/active_record/adapters"

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
    require File.join(AdapterPath,"/#{base_adapter(adapter)}_adapter")
  end

  # Loads the import functionality for the passed in ActiveRecord connection
  def self.load_from_connection_pool(connection_pool)
    require_adapter connection_pool.spec.config[:adapter]
  end
end


this_dir = Pathname.new File.dirname(__FILE__)
require this_dir.join("import").to_s
require this_dir.join("active_record/adapters/abstract_adapter").to_s
require this_dir.join("synchronize").to_s