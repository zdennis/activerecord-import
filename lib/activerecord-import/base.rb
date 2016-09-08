require "pathname"
require "active_record"
require "active_record/version"

module ActiveRecord::Import
  ADAPTER_PATH = "activerecord-import/active_record/adapters".freeze

  def self.base_adapter(adapter)
    case adapter
    when 'mysql2_makara' then 'mysql2'
    when 'mysql2spatial' then 'mysql2'
    when 'spatialite' then 'sqlite3'
    when 'postgresql_makara' then 'postgresql'
    when 'postgis' then 'postgresql'
    when 'redshift' then 'postgresql'
    else adapter
    end
  end

  # Loads the import functionality for a specific database adapter
  def self.require_adapter(adapter)
    require File.join(ADAPTER_PATH, "/abstract_adapter")
    begin
      require File.join(ADAPTER_PATH, "/#{base_adapter(adapter)}_adapter")
    rescue LoadError
      # fallback
    end
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
require this_dir.join("value_sets_parser").to_s
