source :gemcutter

gem "activerecord", "~> 3.0.0"

group :development do
  gem "rake"
  gem "jeweler", ">= 1.4.0"
end

group :test do
  # Database Adapters
  gem "mysql", "~> 2.8.1"
  gem "mysql2", "~> 0.2.4"
  gem "pg", "~> 0.9.0"
  gem "sqlite3-ruby", "~> 1.3.1"

  # Support libs
  gem "factory_girl", "~> 1.3.3"
  gem "delorean", "~> 0.2.0"
  
  # Debugging
  platforms :mri_18 do
    gem "ruby-debug", "~> 0.9.3"
  end

  platforms :mri_19 do
    # TODO: Remove the conditional when ruby-debug19 supports Ruby >= 1.9.3
    gem "ruby-debug19" if RUBY_VERSION < "1.9.3"
  end
end
