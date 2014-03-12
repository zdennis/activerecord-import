source 'https://rubygems.org'

gemspec

# Database Adapters
platforms :ruby do
  gem "em-synchrony",           "~> 1.0.3"
  gem "mysql2",                 "~> 0.3.0"
  gem "pg",                     "~> 0.9"
  gem "sqlite3-ruby",           "~> 1.3.1"
  gem "seamless_database_pool", "~> 1.0.13"
end

platforms :jruby do
  gem "jdbc-mysql"
  gem "jdbc-postgres"
  gem "activerecord-jdbcmysql-adapter"
  gem "activerecord-jdbcpostgresql-adapter"
end

# Support libs
gem "factory_girl", "~> 4.2.0"
gem "delorean",     "~> 0.2.0"

# Debugging
platforms :mri_18 do
  gem "ruby-debug", "= 0.10.4"
end

platforms :jruby do
  gem "ruby-debug-base", "= 0.10.4"
  gem "ruby-debug",      "= 0.10.4"
end

platforms :mri_19 do
  gem "debugger"
end

version = ENV['AR_VERSION'] || "3.2"

eval_gemfile File.expand_path("../gemfiles/#{version}.gemfile", __FILE__)
