require "active_record/connection_adapters/sqlite3_adapter"

module ActiveRecord # :nodoc:
  module ConnectionAdapters # :nodoc:
    class Sqlite3Adapter # :nodoc:
      def next_value_for_sequence(sequence_name)
        %{nextval('#{sequence_name}')}
      end
    end
  end
end
