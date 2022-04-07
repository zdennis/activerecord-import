# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

version = ENV['AR_VERSION'].to_f

mysql2_version = '0.3.0'
mysql2_version = '0.4.0' if version >= 4.2
mysql2_version = '0.5.0' if version >= 6.1
sqlite3_version = '1.3.0'
sqlite3_version = '1.4.0' if version >= 6.0
pg_version = '0.9'
pg_version = '1.1' if version >= 6.1

group :development, :test do
  gem 'rubocop', '~> 0.71.0'
  gem 'rake'
end

# Database Adapters
platforms :ruby do
  gem "mysql2",                 "~> #{mysql2_version}"
  gem "pg",                     "~> #{pg_version}"
  gem "sqlite3",                "~> #{sqlite3_version}"
  # seamless_database_pool requires Ruby ~> 2.0
  gem "seamless_database_pool", "~> 1.0.20" if Gem::Version.new(RUBY_VERSION) < Gem::Version.new('3.0.0')
end

platforms :jruby do
  gem "jdbc-mysql"
  gem "jdbc-postgres"
  gem "activerecord-jdbcsqlite3-adapter",    "~> 1.3"
  gem "activerecord-jdbcmysql-adapter",      "~> 1.3"
  gem "activerecord-jdbcpostgresql-adapter", "~> 1.3"
end

# Support libs
gem "factory_bot"
gem "timecop"
gem "chronic"
gem "mocha", "~> 1.3.0"

# Debugging
platforms :jruby do
  gem "ruby-debug", "= 0.10.4"
end

platforms :ruby do
  gem "pry-byebug"
  gem "pry", "~> 0.12.0"
end

if version >= 4.0
  gem "minitest"
else
  gem "test-unit"
end

eval_gemfile File.expand_path("../gemfiles/#{version}.gemfile", __FILE__)
