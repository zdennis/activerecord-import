module ActiveRecord # :nodoc:
  module ConnectionAdapters # :nodoc:
    class PostgreSQLAdapter # :nodoc:
      def next_value_for_sequence(sequence_name)
        %{nextval('#{sequence_name}')}
      end
    end
  end
end
