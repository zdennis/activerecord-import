require 'spec_helper'

describe 'JDBC Mysql', :adapter => :jdbcmysql do
  include_examples 'mysql import functionality'
end
