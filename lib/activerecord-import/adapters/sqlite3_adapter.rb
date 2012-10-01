module ActiveRecord::Import::SQLite3Adapter
  def next_value_for_sequence(sequence_name)
    %{nextval('#{sequence_name}')}
  end
end
