module ActiveRecord::Import::PostgreSQLAdapter
  include ActiveRecord::Import::ImportSupport

  def next_value_for_sequence(sequence_name)
    %{nextval('#{sequence_name}')}
  end
end
