# rubocop:disable Style/FileName

ActiveSupport.on_load(:active_record) do
  class ActiveRecord::Base
    class << self
      def establish_connection_with_activerecord_import(*args)
        conn = establish_connection_without_activerecord_import(*args)
        if !ActiveRecord.const_defined?(:Import) || !ActiveRecord::Import.respond_to?(:load_from_connection_pool)
          require "activerecord-import/base"
        end

        ActiveRecord::Import.load_from_connection_pool connection_pool
        conn
      end
      alias_method_chain :establish_connection, :activerecord_import
    end
  end
end
