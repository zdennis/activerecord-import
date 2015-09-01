module ActiveRecord::Import::SQLServerAdapter
  include ActiveRecord::Import::ImportSupport

  def insert_many( sql, values, *args )
    columns_names = sql.match(/\((.*)\)/)[1].split(',')
    sql_id_index  = columns_names.index('[id]')
    sql_noid      = if sql_id_index.nil?
      nil
    else
      (sql_id_index == (columns_names.length - 1) ? sql.clone[0].gsub(/\[id\]/, '') : sql.clone[0].gsub(/\[id\],/, ''))
    end


    number_of_inserts = 0
    while !(batch = values.shift(1000)).blank? do
      if sql_id_index
        null_ids     = []
        supplied_ids = []

        batch.each do |value|
          values_sql = value.match(/\((.*)\)/)[1].split(',')
          if values_sql[sql_id_index] == "NULL"
            values_sql.delete_at(sql_id_index)
            null_ids << "(#{values_sql.join(',')})"
          else
            supplied_ids << value
          end
        end

        number_of_inserts += super( sql_noid.clone, null_ids, args ) unless null_ids.empty?
        number_of_inserts += super( sql.clone, supplied_ids, args ) unless supplied_ids.empty?
      else
        number_of_inserts += super( sql.clone, values, args )
      end
    end

    number_of_inserts
  end
end
