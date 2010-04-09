require "active_record/connection_adapters/postgresql_adapter"

require File.join File.dirname(__FILE__),  "base"
ActiveRecord::Extensions.require_adapter "postgresql"
