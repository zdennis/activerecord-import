require 'spec_helper'

describe 'EventMachine Mysql2', :adapter => :em_mysql2 do
  include_examples 'mysql import functionality'
end
