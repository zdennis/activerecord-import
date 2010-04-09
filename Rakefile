require 'rake/testtask'

task :default => ["display:notice"]

ADAPTERS = %w(mysql postgresql sqlite3 oracle)

namespace :display do
  task :notice do
    puts
    puts "To run tests you must supply the adapter, see rake -T for more information."
    puts
  end
end

desc "Runs generic database tests."
Rake::TestTask.new("test") { |t|
  t.test_files = FileList["test/*_test.rb", "test/#{ENV['ARE_DB']}/**/*_test.rb"]
}

ADAPTERS.each do |adapter|
  namespace :test do
    desc "Runs unit tests for #{adapter} specific functionality"
    task adapter do
      ENV["ARE_DB"] = adapter
      exec "rake test"
      # exec replaces the current process, never gets here
    end
  end
end
