require "active_record"
require "active_record/version"

module ActiveRecord::Extensions
  AdapterPath = File.join File.expand_path(File.dirname(__FILE__)), "/../active_record/adapters"
  
  def self.require_adapter(adapter)
    require File.join(AdapterPath,"/#{adapter}_adapter")
  end
end

require "ar-extensions/import"
require "ar-extensions/active_record/adapters/abstract_adapter"
