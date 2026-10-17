# frozen_string_literal: true

require "pathname"
require "concurrent/map"
require "active_record"
require "active_record/version"

module ActiveRecord::Import
  ADAPTER_PATH = "activerecord-import/active_record/adapters"
  ATTEMPTED_ADAPTERS = Concurrent::Map.new # :nodoc:

  def self.base_adapter(adapter)
    case adapter
    when 'mysql2_makara' then 'mysql2'
    when 'mysql2spatial' then 'mysql2'
    when 'janus_mysql2' then 'mysql2'
    when 'spatialite' then 'sqlite3'
    when 'postgresql_makara' then 'postgresql'
    when 'makara_postgis' then 'postgresql'
    when 'postgis' then 'postgresql'
    when 'cockroachdb' then 'postgresql'
    when 'janus_trilogy' then 'trilogy'
    else adapter
    end
  end

  # Loads the import functionality for a specific database adapter
  def self.require_adapter(adapter)
    require File.join(ADAPTER_PATH, "/#{base_adapter(adapter)}_adapter")
  rescue LoadError
    # fallback
  end

  # Loads the import functionality for the passed in ActiveRecord connection
  def self.load_from_connection_pool(connection_pool)
    require_adapter adapter_for(connection_pool)
  end

  # Loads the import functionality for the passed in ActiveRecord connection,
  # unless it's been tried for the connection's adapter already. Import uses
  # this when activerecord-import was required after the connection was
  # established. Each adapter is only tried once, so an unsupported adapter
  # doesn't search the load path on every import.
  def self.load_from_connection_pool_once(connection_pool)
    adapter = adapter_for(connection_pool)
    ATTEMPTED_ADAPTERS.compute_if_absent(adapter) do
      require_adapter adapter
      true
    end
  end

  def self.adapter_for(connection_pool) # :nodoc:
    connection_pool.db_config.adapter
  end
  private_class_method :adapter_for
end

require 'activerecord-import/import'
require 'activerecord-import/active_record/adapters/abstract_adapter'
require 'activerecord-import/synchronize'
require 'activerecord-import/value_sets_parser'
require 'activerecord-import/aliases'
