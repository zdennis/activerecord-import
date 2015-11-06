module ActiveRecord::Import::PostgreSQLAdapter
  include ActiveRecord::Import::ImportSupport

  def insert_many( sql, values, *args ) # :nodoc:
    number_of_inserts = 1

    base_sql,post_sql = if sql.is_a?( String )
      [ sql, '' ]
    elsif sql.is_a?( Array )
      [ sql.shift, sql.join( ' ' ) ]
    end

    sql2insert = base_sql + values.join( ',' ) + post_sql
    ids = select_values( sql2insert, *args )

    [number_of_inserts,ids]
  end

  def next_value_for_sequence(sequence_name)
    %{nextval('#{sequence_name}')}
  end

  def post_sql_statements( table_name, options ) # :nodoc:
    unless options[:primary_key].blank?
      super(table_name, options) << (" RETURNING #{options[:primary_key]}")
    else
      super(table_name, options)
    end
  end

  # Returns a generated ON DUPLICATE KEY UPDATE statement given the passed
  # in +args+.
  def sql_for_on_duplicate_constraint_update( table_name, options = {} ) # :nodoc:
    sql = " ON CONFLICT (#{options[:constraint]}) DO UPDATE SET "
    sql << sql_for_on_duplicate_key_update_as_array( table_name, options[:keys] )
    sql
  end

  def sql_for_on_duplicate_key_update_as_array( table_name, arr )  # :nodoc:
    results = arr.map do |column|
      "#{column}=EXCLUDED.#{column}"
    end
    results.join( ',' )
  end

  def support_setting_primary_key_of_imported_objects?
    true
  end
end
