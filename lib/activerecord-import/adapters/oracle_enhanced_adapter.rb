module ActiveRecord::Import::OracleEnhancedAdapter
  module InstanceMethods
    def next_value_for_sequence(sequence_name)
      %{#{sequence_name}.nextval}
    end
  end
end
