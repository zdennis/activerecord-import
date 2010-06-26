require "pathname"
require "active_record"
require "active_record/version"

module ActiveRecord::Extensions
  AdapterPath = File.join File.expand_path(File.dirname(__FILE__)), "/../active_record/adapters"
  
  def self.require_adapter(adapter)
    require File.join(AdapterPath,"/#{adapter}_adapter")
  end
end

this_dir = Pathname.new File.dirname(__FILE__)
require this_dir.join("import")
require this_dir.join("active_record/adapters/abstract_adapter")
