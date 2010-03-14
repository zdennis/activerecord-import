require 'rake/testtask'

task :default => [:test]

ADAPTERS = %w(mysql postgresql sqlite sqlite3 oracle)

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
