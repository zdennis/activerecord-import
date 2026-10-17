# frozen_string_literal: true

module ActiveRecord::Import::AbstractAdapter
  module InstanceMethods
    def next_value_for_sequence(sequence_name)
      %(#{sequence_name}.nextval)
    end

    def insert_many( sql, values, _options = {}, *args ) # :nodoc:
      number_of_inserts = 1

      base_sql, post_sql = case sql
                           when String
                             [sql, '']
                           when Array
                             [sql.shift, sql.join( ' ' )]
      end

      sql2insert = base_sql + values.join( ',' ) + post_sql
      insert( sql2insert, *args )

      ActiveRecord::Import::Result.new([], number_of_inserts, [], [])
    end

    def pre_sql_statements(options)
      sql = []
      sql << options[:pre_sql] if options[:pre_sql]
      sql << options[:command] if options[:command]

      # add keywords like IGNORE or DELAYED
      if options[:keywords].is_a?(Array)
        sql.concat(options[:keywords])
      elsif options[:keywords]
        sql << options[:keywords].to_s
      end

      sql
    end

    # Synchronizes the passed in ActiveRecord instances with the records in
    # the database by calling +reload+ on each instance.
    def after_import_synchronize( instances )
      instances.each(&:reload)
    end

    # Returns an array of post SQL statements given the passed in options.
    def post_sql_statements( table_name, options ) # :nodoc:
      post_sql_statements = []

      if supports_on_duplicate_key_update? && options[:on_duplicate_key_update]
        post_sql_statements << sql_for_on_duplicate_key_update( table_name, options[:on_duplicate_key_update], options[:model], options[:primary_key], options[:locking_column] )
      elsif logger && options[:on_duplicate_key_update]
        logger.warn "Ignoring on_duplicate_key_update because it is not supported by the database."
      end

      # custom user post_sql
      post_sql_statements << options[:post_sql] if options[:post_sql]

      # with rollup
      post_sql_statements << rollup_sql if options[:rollup]

      post_sql_statements
    end

    # Returns the selections for an INSERT ... RETURNING clause: the primary key
    # and any +:returning+ columns. Known columns are quoted, anything else (such
    # as raw SQL) is returned unchanged.
    def returning_selections(options)
      selections = []
      column_names = Array(options[:model]&.column_names)

      selections += Array(options[:primary_key]) if options[:primary_key].present?
      selections += Array(options[:returning]) if options[:returning].present?

      selections.map do |selection|
        column_names.include?(selection.to_s) ? quote_column_name(selection) : selection
      end
    end

    # Splits the values returned by an INSERT ... RETURNING into the ids and the
    # +:returning+ results. +returned_values+ is a Hash with the returned
    # +:values+, and the +:columns+ when more than one column was returned.
    def ids_and_results_from_returned_values( returned_values, options ) # :nodoc:
      if options[:returning].blank?
        [Array(returned_values[:values]), []]
      elsif options[:primary_key].blank?
        options[:returning_columns] ||= returned_values[:columns]
        [[], Array(returned_values[:values])]
      else
        # split primary key and returning columns
        ids, results, options[:returning_columns] = split_ids_and_results(returned_values, options)
        [ids, results]
      end
    end

    def split_ids_and_results( selections, options )
      ids = []
      returning_values = []

      columns = Array(selections[:columns])
      values = Array(selections[:values])
      id_indexes = Array(options[:primary_key]).map { |key| columns.index(key) }
      returning_columns = columns.reject.with_index { |_, index| id_indexes.include?(index) }
      returning_indexes = returning_columns.map { |column| columns.index(column) }

      values.each do |value|
        value_array = Array(value)
        ids << id_indexes.map { |index| value_array[index] }
        returning_values << returning_indexes.map { |index| value_array[index] }
      end

      ids.map!(&:first) if id_indexes.size == 1
      returning_values.map!(&:first) if returning_columns.size == 1

      [ids, returning_values, returning_columns]
    end

    def increment_locking_column!(table_name, results, locking_column)
      if locking_column.present?
        results << "\"#{locking_column}\"=#{table_name}.\"#{locking_column}\"+1"
      end
    end

    def supports_on_duplicate_key_update?
      false
    end

    # Whether a value in an INSERT's VALUES can be DEFAULT, to use the column's default
    def supports_default_keyword_in_values?
      true
    end
  end
end
