# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

version = ENV['AR_VERSION'].to_f

mysql2_version = '0.5.0'
mysql2_version = '0.5.6' if version >= 8.0
sqlite3_version = '1.4.0'
sqlite3_version = '2.2.0' if version >= 8.0
pg_version = '1.1'
pg_version = '1.5' if version >= 8.0

group :development, :test do
  gem 'rubocop'
  gem 'rake'
end

# Database Adapters
platforms :ruby do
  gem "mysql2",                 "~> #{mysql2_version}"
  gem "pg",                     "~> #{pg_version}"
  gem "sqlite3",                "~> #{sqlite3_version}"
  gem "trilogy"
  gem "activerecord-trilogy-adapter" if version <= 7.0
end

platforms :jruby do
  gem "jdbc-mysql"
  gem "jdbc-postgres"
  gem "activerecord-jdbcsqlite3-adapter"
  gem "activerecord-jdbcmysql-adapter"
  gem "activerecord-jdbcpostgresql-adapter"
end

# Support libs
gem "factory_bot"
gem "timecop"
gem "chronic"
gem "mocha", "~> 2.1.0"

# Debugging
platforms :ruby do
  gem "pry-byebug"
  gem "pry", "~> 0.14.0"
end

gem "minitest"

# Used by benchmarks/ to write CSV results. csv is no longer a default gem as of Ruby 3.4.
gem "csv"

# json 3.0 changed JSON.generate and JSON.parse in ways ActiveSupport isn't
# compatible with (e.g. quirks_mode), breaking serialized attributes.
gem "json", "< 3"

# mutex_m, drb, base64, bigdecimal moved from default gems to bundled gems in Ruby 3.4.0.
# ActiveSupport 6.1-7.0 don't include these gems as dependencies, so they must be explicitly required.
# ActiveSupport 7.1+ includes them as dependencies or not required, so no explicit inclusion is needed.
if version >= 6.1 && version <= 7.0 && Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('3.4.0')
  gem "mutex_m"
  gem "drb"
  gem "base64"
  gem "bigdecimal"
end

eval_gemfile File.expand_path("../gemfiles/#{version}.gemfile", __FILE__)
