source :gemcutter

gem "activerecord", "~> 3.0"

group :development do
  gem "rake"
  gem "jeweler", ">= 1.4.0"
end

group :test do
  # Database Adapters
  platforms :ruby do
    gem "mysql", "~> 2.8.1"
    gem "mysql2", "~> 0.3.0"
    gem "pg", "~> 0.9"
    gem "sqlite3-ruby", "~> 1.3.1"
    gem "seamless_database_pool", "~> 1.0.11"
  end

  platforms :jruby do
    gem "jdbc-mysql"
    gem "activerecord-jdbcmysql-adapter"
  end

  # Support libs
  gem "factory_girl", "~> 1.3.3"
  gem "delorean", "~> 0.2.0"

  # Debugging
  platforms :mri_18 do
    gem "ruby-debug", "= 0.10.4"
  end

  platforms :jruby do
    gem "ruby-debug-base", "= 0.10.4"
    gem "ruby-debug", "= 0.10.4"
  end

  platforms :mri_19 do
    gem "debugger"
  end
end
