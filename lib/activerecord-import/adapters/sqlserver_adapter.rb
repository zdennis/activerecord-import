module ActiveRecord::Import::SQLServerAdapter
  include ActiveRecord::Import::ImportSupport

  # There is a limit of 1000 rows on the insert method
  # We need to process it in batches
  def insert_many( sql, values, *args ) # :nodoc:
    number_of_inserts = 0
    while !(batch = values.shift(1000)).blank? do
      # cloning sql here since the super method is modifying it
      number_of_inserts += super( sql.clone, batch, args )
    end
    number_of_inserts
  end

end
