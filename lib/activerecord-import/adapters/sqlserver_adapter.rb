module ActiveRecord::Import::SQLServerAdapter
  include ActiveRecord::Import::ImportSupport

  # There is a limit of 1000 rows on the insert method
  # We need to process it in batches
  def insert_many( sql, values, *args ) # :nodoc:
    #HACK, SQLSERVER doesn't allow you to specify ID as NULL
#    sql[0].gsub!("[id],","")
#    values.each do |value| 
#      value.gsub!(/^\(NULL,/,"(")
#    end

    number_of_inserts = 0
    while !(batch = values.shift(1000)).blank? do
      nullids =[]
      suppliedids=[]
      batch.each do |value|
        if value.match(/^\(NULL,/) then
           nullids << value.gsub(/^\(NULL,/,"(")
        else
           suppliedids << value
        end
      end

      number_of_inserts += super( sql.clone[0].gsub!(/\[id\],/,""), nullids, args ) unless nullids.empty?
      number_of_inserts += super( sql.clone, suppliedids, args ) unless suppliedids.empty?
      # cloning sql here since the super method is modifying it
      #number_of_inserts += super( sql.clone, batch, args )
    end
    number_of_inserts
  end

end
