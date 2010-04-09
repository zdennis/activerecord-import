begin ; require 'rubygems' ; rescue LoadError ; end
require 'active_record' # ActiveRecord loads the Benchmark library automatically
require 'active_record/version'
require 'fastercsv'
require 'fileutils'
require 'logger'

# Files are loaded alphabetically. If this is a problem then manually specify the files
# that need to be loaded here.
Dir[ File.join( File.dirname( __FILE__ ), 'lib', '*.rb' ) ].sort.each{ |f| require f }

ActiveRecord::Base.logger = Logger.new STDOUT






