require 'spec_helper'

describe 'Mysql2 Spatial', :adapter => :mysql2spatial do
  include_examples 'mysql import functionality'
end
