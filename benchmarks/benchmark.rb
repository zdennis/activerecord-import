require "pathname"
this_dir = Pathname.new File.dirname(__FILE__)
require this_dir.join('boot')

# Parse the options passed in via the command line
options = BenchmarkOptionParser.parse( ARGV )

# The support directory where we use to load our connections and models for the 
# benchmarks.
SUPPORT_DIR = this_dir.join('../test')

# Load the database adapter
adapter = options.adapter

# load the library
LIB_DIR = this_dir.join("../lib")
require LIB_DIR.join("activerecord-import/#{adapter}")

ActiveRecord::Base.logger = Logger.new("log/test.log")
ActiveRecord::Base.logger.level = Logger::DEBUG
ActiveRecord::Base.configurations["test"] = YAML.load(SUPPORT_DIR.join("database.yml").open)[adapter]
ActiveRecord::Base.establish_connection "test"

ActiveSupport::Notifications.subscribe(/active_record.sql/) do |event, _, _, _, hsh|
  ActiveRecord::Base.logger.info hsh[:sql]
end

adapter_schema = SUPPORT_DIR.join("schema/#{adapter}_schema.rb")
require adapter_schema if File.exists?(adapter_schema)
Dir[this_dir.join("models/*.rb")].each{ |file| require file }

# Load databse specific benchmarks
require File.join( File.dirname( __FILE__ ), 'lib', "#{adapter}_benchmark" )

# TODO implement method/table-type selection
table_types = nil
if options.benchmark_all_types
  table_types = [ "all" ]
else
  table_types = options.table_types.keys
end
puts

letter = options.adapter[0].chr
clazz_str = letter.upcase + options.adapter[1..-1].downcase
clazz = Object.const_get( clazz_str + "Benchmark" )

benchmarks = []
options.number_of_objects.each do |num|
  benchmarks << (benchmark = clazz.new)
  benchmark.send( "benchmark", table_types, num )
end

options.outputs.each do |output|
  format = output.format.downcase
  output_module = Object.const_get( "OutputTo#{format.upcase}" )
  benchmarks.each do |benchmark|
    output_module.output_results( output.filename, benchmark.results )
  end
end

puts
puts "Done with benchmark!"

