require 'rake/testtask'

task :default => ["display:notice"]

ADAPTERS = %w(mysql postgresql sqlite3)

namespace :display do
  task :notice do
    puts
    puts "To run tests you must supply the adapter, see rake -T for more information."
    puts
  end
end

ADAPTERS.each do |adapter|
  namespace :test do
    desc "Runs #{adapter} database tests."
    Rake::TestTask.new(adapter) do |t|
      t.test_files = FileList["test/adapters/#{adapter}.rb", "test/*_test.rb", "test/#{adapter}/**/*_test.rb"]
    end
  end
end
