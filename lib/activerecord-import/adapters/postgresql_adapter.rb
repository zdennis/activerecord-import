module ActiveRecord::Import::PostgreSQLAdapter
  include ActiveRecord::Import::ImportSupport

  def increment_sequence_and_get_next_id(sequence_name, increment_by)
    result = execute(<<-SQL
    select
      nextval('#{sequence_name}') as next_id,
      setval(
        '#{sequence_name}',
        currval('#{sequence_name}'
      ) + #{increment_by - 1}) as next_available_id
    SQL
    ).first
    if result && next_id = result['next_id']
      next_id.to_i
    else
      raise %{Could not update sequence: "#{sequence_name}"}
    end
  end

  def next_value_for_sequence(sequence_name)
    %{nextval('#{sequence_name}')}
  end
end
