# frozen_string_literal: true

module ActiveRecord::Import::MysqlAdapter
  include ActiveRecord::Import::ImportSupport
  include ActiveRecord::Import::OnDuplicateKeyUpdateSupport

  NO_MAX_PACKET = 0
  QUERY_OVERHEAD = 8 # This was shown to be true for MySQL, but it's not clear where the overhead is from.
  MIN_MARIADB_VERSION_FOR_RETURNING = "10.5.0"

  # +sql+ can be a single string or an array. If it is an array all
  # elements that are in position >= 1 will be appended to the final SQL.
  def insert_many( sql, values, options = {}, *args ) # :nodoc:
    # the number of inserts default
    number_of_inserts = 0
    affected_rows = nil
    returning = import_returning?( options )
    returned_columns = []
    returned_rows = []

    base_sql, post_sql = case sql
                         when String
                           [sql, '']
                         when Array
                           [sql.shift, sql.join( ' ' )]
    end

    sql_size = QUERY_OVERHEAD + base_sql.bytesize + post_sql.bytesize

    # the number of bytes the requested insert statement values will take up
    values_in_bytes = values.sum(&:bytesize)

    # the number of bytes (commas) it will take to comma separate our values
    comma_separated_bytes = values.size - 1

    # the total number of bytes required if this statement is one statement
    total_bytes = sql_size + values_in_bytes + comma_separated_bytes

    max = max_allowed_packet

    insert_value_set = lambda do |value_set|
      number_of_inserts += 1
      sql2insert = base_sql + value_set.join( ',' ) + post_sql

      if returning
        result = exec_query( sql2insert, *args )
        returned_columns = result.columns
        returned_rows.concat(result.rows)

        if result.respond_to?(:affected_rows) && result.affected_rows
          affected_rows = (affected_rows || 0) + result.affected_rows
        end
      else
        # Unlike #execute, whose result only has the affected rows with some drivers
        # (e.g. trilogy, but not mysql2), #exec_update returns them with every driver
        count = exec_update( sql2insert, *args )
        affected_rows = (affected_rows || 0) + count if count.is_a?(Integer)
      end
    end

    # if we can insert it all as one statement
    if max == NO_MAX_PACKET || total_bytes <= max || options[:force_single_insert]
      insert_value_set.call(values)
    else
      value_sets = ::ActiveRecord::Import::ValueSetsBytesParser.parse(values,
        reserved_bytes: sql_size,
        max_bytes: max)

      transaction(requires_new: true) do
        value_sets.each { |value_set| insert_value_set.call(value_set) }
      end
    end

    # ActiveRecord < 7.1 doesn't clear the query cache for #execute or #exec_query
    clear_query_cache if query_cache_enabled

    ids = []
    results = []

    if returning
      returned_values = if returned_columns.size > 1
        { values: returned_rows, columns: returned_columns }
      else
        { values: returned_rows.map(&:first) }
      end
      ids, results = ids_and_results_from_returned_values(returned_values, options)
    end

    ActiveRecord::Import::Result.new([], number_of_inserts, ids, results, affected_rows)
  end

  # Returns the maximum number of bytes that the server will allow
  # in a single packet
  def max_allowed_packet # :nodoc:
    @max_allowed_packet ||= begin
      result = execute( "SELECT @@max_allowed_packet" )
      # original Mysql gem responds to #fetch_row while Mysql2 responds to #first
      val = result.respond_to?(:fetch_row) ? result.fetch_row[0] : result.first[0]
      val.to_i
    end
  end

  def pre_sql_statements( options)
    sql = []
    # Recursive imports need the id of every model, which INSERT IGNORE doesn't return
    # for ignored rows, so :ignore and :on_duplicate_key_ignore don't apply to them.
    if (options[:ignore] || options[:on_duplicate_key_ignore]) && !(options[:recursive] && supports_setting_primary_key_of_imported_objects?)
      sql << "IGNORE"
    end
    sql + super
  end

  def post_sql_statements( table_name, options ) # :nodoc:
    sql = super
    sql << "RETURNING #{returning_selections(options).join(', ')}" if import_returning?( options )
    sql
  end

  # MariaDB 10.5+ supports INSERT ... RETURNING, so the ids of imported models
  # can be set. MySQL doesn't support it.
  def supports_setting_primary_key_of_imported_objects?
    respond_to?(:mariadb?) && mariadb? && database_version >= MIN_MARIADB_VERSION_FOR_RETURNING
  end

  # Returns true if the import should use INSERT ... RETURNING
  def import_returning?( options ) # :nodoc:
    supports_setting_primary_key_of_imported_objects? &&
      returning_selections(options).present? &&
      !(options[:no_returning] && !options[:recursive])
  end

  # Add a column to be updated on duplicate key update
  def add_column_for_on_duplicate_key_update( column, options = {} ) # :nodoc:
    if (columns = options[:on_duplicate_key_update])
      case columns
      when Array then columns << column.to_sym unless columns.include?(column.to_sym)
      when Hash then columns[column.to_sym] = column.to_sym
      end
    end
  end

  # Returns a generated ON DUPLICATE KEY UPDATE statement given the passed
  # in +args+.
  def sql_for_on_duplicate_key_update( table_name, *args ) # :nodoc:
    sql = ' ON DUPLICATE KEY UPDATE '.dup
    arg, model, _primary_key, locking_column = args
    case arg
    when Array
      sql << sql_for_on_duplicate_key_update_as_array( table_name, model, locking_column, arg )
    when Hash
      sql << sql_for_on_duplicate_key_update_as_hash( table_name, model, locking_column, arg )
    when String
      sql << arg
    else
      raise ArgumentError, "Expected Array or Hash"
    end
    sql
  end

  def sql_for_on_duplicate_key_update_as_array( table_name, model, locking_column, arr ) # :nodoc:
    results = arr.map do |column|
      original_column_name = model.column_name_for_import( column )
      qc = quote_column_name( original_column_name )
      "#{table_name}.#{qc}=VALUES(#{qc})"
    end
    increment_locking_column!(table_name, results, locking_column)
    results.join( ',' )
  end

  def sql_for_on_duplicate_key_update_as_hash( table_name, model, locking_column, hsh ) # :nodoc:
    results = hsh.map do |column1, column2|
      original_column1_name = model.column_name_for_import( column1 )
      qc1 = quote_column_name( original_column1_name )

      original_column2_name = model.column_name_for_import( column2 )
      qc2 = quote_column_name( original_column2_name )

      "#{table_name}.#{qc1}=VALUES( #{qc2} )"
    end
    increment_locking_column!(table_name, results, locking_column)
    results.join( ',')
  end

  # Return true if the statement is a duplicate key record error
  def duplicate_key_update_error?(exception) # :nodoc:
    exception.is_a?(ActiveRecord::StatementInvalid) && exception.to_s.include?('Duplicate entry')
  end

  def increment_locking_column!(table_name, results, locking_column)
    if locking_column.present?
      results << "`#{locking_column}`=#{table_name}.`#{locking_column}`+1"
    end
  end
end
