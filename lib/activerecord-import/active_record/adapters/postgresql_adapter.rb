require "active_record/connection_adapters/postgresql_adapter"
require "activerecord-import/adapters/postgresql_adapter"

class ActiveRecord::ConnectionAdapters::PostgreSQLAdapter
  include ActiveRecord::Import::PostgreSQLAdapter

  alias_method :post_sql_statements_orig, :post_sql_statements
  def post_sql_statements( table_name, options ) # :nodoc:
    post_sql_statements_orig(table_name, options).append(" RETURNING ID")
  end

end

