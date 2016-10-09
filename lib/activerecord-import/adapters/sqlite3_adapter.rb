module ActiveRecord::Import::SQLite3Adapter
  include ActiveRecord::Import::ImportSupport

  MIN_VERSION_FOR_IMPORT = "3.7.11".freeze
  SQLITE_LIMIT_COMPOUND_SELECT = 500

  # Override our conformance to ActiveRecord::Import::ImportSupport interface
  # to ensure that we only support import in supported version of SQLite.
  # Which INSERT statements with multiple value sets was introduced in 3.7.11.
  def supports_import?(current_version = sqlite_version)
    if current_version >= MIN_VERSION_FOR_IMPORT
      true
    else
      false
    end
  end

  # +sql+ can be a single string or an array. If it is an array all
  # elements that are in position >= 1 will be appended to the final SQL.
  def insert_many(sql, values, *args) # :nodoc:
    number_of_inserts = 0
    ids = []

    base_sql, post_sql = if sql.is_a?( String )
      [sql, '']
    elsif sql.is_a?( Array )
      [sql.shift, sql.join( ' ' )]
    end

    value_sets = ::ActiveRecord::Import::ValueSetsRecordsParser.parse(values,
      max_records: SQLITE_LIMIT_COMPOUND_SELECT)

    transaction(requires_new: true) do
      value_sets.each do |value_set|
        number_of_inserts += 1
        sql2insert = base_sql + value_set.join( ',' ) + post_sql
        last_insert_id = insert( sql2insert, *args )
        first_insert_id = last_insert_id - affected_rows + 1
        ids.concat((first_insert_id..last_insert_id).to_a)
      end
    end

    [number_of_inserts, ids]
  end

  def pre_sql_statements( options)
    sql = []
    # Options :recursive and :on_duplicate_key_ignore are mutually exclusive
    if (options[:ignore] || options[:on_duplicate_key_ignore]) && !options[:recursive]
      sql << "OR IGNORE"
    end
    sql + super
  end

  def next_value_for_sequence(sequence_name)
    %{nextval('#{sequence_name}')}
  end

  def affected_rows
    result = execute('SELECT changes();')
    result.first[0]
  end

  def support_setting_primary_key_of_imported_objects?
    true
  end
end
