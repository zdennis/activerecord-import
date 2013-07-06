require 'spec_helper'

describe 'Mysql2', :adapter => :mysql2 do
  include_examples 'mysql import functionality'
end
