module ActiveRecord::Import::SQLServerAdapter
  include ActiveRecord::Import::ImportSupport

  # There is a limit of 1000 rows on the insert method
  # We need to process it in batches
  def insert_many( sql, values, *args ) # :nodoc:
    noidsql = sql.clone[0].gsub(/\[id\],/,"")
    
    number_of_inserts = 0
    while !(batch = values.shift(1000)).blank? do
      #If the ID is NULL, insert without the ID column so SQLserver will add it
      #If we are supplied the id, include it in the column list.
      nullids =[]
      suppliedids=[]
      batch.each do |value|
        #If the first argument (id) is null remove it.
        #this is assuming id is first. We should probably check where id is based on the SQL cmd
        if value.match(/^\(NULL,/) then
           nullids << value.gsub(/^\(NULL,/,"(")
        else
           #we got given the ID so just use this value as is
           suppliedids << value
        end
      end
      #run two SQL bulk inserts. One in which we remove the NULL ids and let Sqlserver figure them out
      #the other in which we use the ids as supplied
      number_of_inserts += super( noidsql.clone, nullids, args ) unless nullids.empty?
      number_of_inserts += super( sql.clone, suppliedids, args ) unless suppliedids.empty?
    end
    number_of_inserts
  end

end
