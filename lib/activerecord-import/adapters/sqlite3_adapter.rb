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
  def insert_many( sql, values, _options = {}, *args ) # :nodoc:
    number_of_inserts = 0

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
        insert( sql2insert, *args )
      end
    end

    [number_of_inserts, []]
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
end
