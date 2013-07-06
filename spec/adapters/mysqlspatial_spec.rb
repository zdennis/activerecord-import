require 'spec_helper'

describe 'Mysql Spatial', :adapter => :mysqlspatial do
  include_examples 'mysql import functionality'
end
