require "activerecord-import/adapters/abstract_adapter"

module ActiveRecord # :nodoc:
  module ConnectionAdapters # :nodoc:
    class AbstractAdapter # :nodoc:
      extend ActiveRecord::Extensions::Import::AbstractAdapter::ClassMethods
      include ActiveRecord::Extensions::Import::AbstractAdapter::InstanceMethods
    end
  end
end
