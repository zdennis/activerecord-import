module ActiveRecord::Import::PostgreSQLAdapter
  include ActiveRecord::Import::ImportSupport
  include ActiveRecord::Import::OnDuplicateKeyUpdateSupport

  MIN_VERSION_FOR_UPSERT = 90_500

  def insert_many( sql, values, *args ) # :nodoc:
    number_of_inserts = 1

    base_sql, post_sql = if sql.is_a?( String )
      [sql, '']
    elsif sql.is_a?( Array )
      [sql.shift, sql.join( ' ' )]
    end

    sql2insert = base_sql + values.join( ',' ) + post_sql
    ids = select_values( sql2insert, *args )

    ActiveRecord::Base.connection.query_cache.clear

    [number_of_inserts, ids]
  end

  def next_value_for_sequence(sequence_name)
    %{nextval('#{sequence_name}')}
  end

  def post_sql_statements( table_name, options ) # :nodoc:
    if options[:primary_key].blank?
      super(table_name, options)
    else
      super(table_name, options) << "RETURNING #{options[:primary_key]}"
    end
  end

  # Add a column to be updated on duplicate key update
  def add_column_for_on_duplicate_key_update( column, options = {} ) # :nodoc:
    arg = options[:on_duplicate_key_update]
    if arg.is_a?( Hash )
      columns = arg.fetch( :columns ) { arg[:columns] = [] }
      case columns
      when Array then columns << column.to_sym unless columns.include?( column.to_sym )
      when Hash then columns[column.to_sym] = column.to_sym
      end
    elsif arg.is_a?( Array )
      arg << column.to_sym unless arg.include?( column.to_sym )
    end
  end

  # Returns a generated ON CONFLICT DO NOTHING statement given the passed
  # in +args+.
  def sql_for_on_duplicate_key_ignore( table_name, *args ) # :nodoc:
    arg = args.first
    conflict_target = sql_for_conflict_target( arg ) if arg.is_a?( Hash )
    " ON CONFLICT #{conflict_target}DO NOTHING"
  end

  # Returns a generated ON CONFLICT DO UPDATE statement given the passed
  # in +args+.
  def sql_for_on_duplicate_key_update( table_name, *args ) # :nodoc:
    arg = args.first
    arg = { columns: arg } if arg.is_a?( Array ) || arg.is_a?( String )
    return unless arg.is_a?( Hash )

    sql = " ON CONFLICT "
    conflict_target = sql_for_conflict_target( arg )

    columns = arg.fetch( :columns, [] )
    if columns.respond_to?( :empty? ) && columns.empty?
      return sql << "#{conflict_target}DO NOTHING"
    end

    conflict_target ||= sql_for_default_conflict_target( table_name )
    unless conflict_target
      raise ArgumentError, 'Expected :conflict_target or :constraint_name to be specified'
    end

    sql << "#{conflict_target}DO UPDATE SET "
    if columns.is_a?( Array )
      sql << sql_for_on_duplicate_key_update_as_array( table_name, columns )
    elsif columns.is_a?( Hash )
      sql << sql_for_on_duplicate_key_update_as_hash( table_name, columns )
    elsif columns.is_a?( String )
      sql << columns
    else
      raise ArgumentError, 'Expected :columns to be an Array or Hash'
    end
    sql
  end

  def sql_for_on_duplicate_key_update_as_array( table_name, arr ) # :nodoc:
    results = arr.map do |column|
      qc = quote_column_name( column )
      "#{qc}=EXCLUDED.#{qc}"
    end
    results.join( ',' )
  end

  def sql_for_on_duplicate_key_update_as_hash( table_name, hsh ) # :nodoc:
    results = hsh.map do |column1, column2|
      qc1 = quote_column_name( column1 )
      qc2 = quote_column_name( column2 )
      "#{qc1}=EXCLUDED.#{qc2}"
    end
    results.join( ',' )
  end

  def sql_for_conflict_target( args = {} )
    constraint_name = args[:constraint_name]
    conflict_target = args[:conflict_target]
    if constraint_name
      "ON CONSTRAINT #{constraint_name} "
    elsif conflict_target
      '(' << Array( conflict_target ).join( ', ' ) << ') '
    end
  end

  def sql_for_default_conflict_target( table_name )
    "(#{primary_key( table_name )}) "
  end

  # Return true if the statement is a duplicate key record error
  def duplicate_key_update_error?(exception) # :nodoc:
    exception.is_a?(ActiveRecord::StatementInvalid) && exception.to_s.include?('duplicate key')
  end

  def supports_on_duplicate_key_update?(current_version = postgresql_version)
    current_version >= MIN_VERSION_FOR_UPSERT
  end

  def supports_on_duplicate_key_ignore?(current_version = postgresql_version)
    supports_on_duplicate_key_update?(current_version)
  end

  def support_setting_primary_key_of_imported_objects?
    true
  end
end
