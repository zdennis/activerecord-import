# frozen_string_literal: true

require 'pathname'
require 'rake'
require 'logger'
require 'erb'
require 'json'

test_dir = Pathname.new File.dirname(__FILE__)
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

require "fileutils"

ENV["RAILS_ENV"] = "test"

require "bundler"
Bundler.setup

unless RbConfig::CONFIG["RUBY_INSTALL_NAME"] =~ /jruby/
  require 'pry'
  require 'pry-byebug'
end

require "active_record"
require "active_record/fixtures"
require "active_support/test_case"
require 'minitest/autorun'
require "mocha/minitest"

require 'timecop'
require 'chronic'

# Before ActiveRecord 7.1, composite primary keys need the composite_primary_keys gem.
# 7.1 and later support them natively, so the composite primary key tests run without it.
begin
  require 'composite_primary_keys'
rescue LoadError
  if ENV['AR_VERSION'].to_f < 7.1
    ENV['SKIP_COMPOSITE_PK'] = 'true'
  end
end

adapter = ENV["ARE_DB"] || "sqlite3"

FileUtils.mkdir_p 'log'
ActiveRecord::Base.logger = Logger.new("log/test.log")
ActiveRecord::Base.logger.level = Logger::DEBUG

if ActiveRecord.respond_to?(:use_yaml_unsafe_load)
  ActiveRecord.use_yaml_unsafe_load = true
elsif ActiveRecord::Base.respond_to?(:use_yaml_unsafe_load)
  ActiveRecord::Base.use_yaml_unsafe_load = true
end

# Without a test/database.yml, use the committed default, which is configured with
# environment variables and defaults to the databases in docker-compose.yml.
database_yml = test_dir.join("database.yml")
database_yml = test_dir.join("database.default.yml") unless database_yml.exist?
database_yml_content = ERB.new(database_yml.read).result
databases = if Gem::Version.new(Psych::VERSION) >= Gem::Version.new('3.2.1')
  YAML.safe_load(database_yml_content, aliases: true)
else
  YAML.load(database_yml_content)
end
yaml_config = databases[adapter] || raise("#{database_yml} has no configuration for #{adapter}")

if ENV['AR_VERSION'].to_f >= 6.0
  config = ActiveRecord::DatabaseConfigurations::HashConfig.new("test", adapter, yaml_config)
  ActiveRecord::Base.configurations.configurations << config
else
  ActiveRecord::Base.configurations["test"] = yaml_config
end

if ActiveRecord.respond_to?(:default_timezone)
  ActiveRecord.default_timezone = :utc
else
  ActiveRecord::Base.default_timezone = :utc
end

require "activerecord-import"
ActiveRecord::Base.establish_connection :test

ActiveSupport::Notifications.subscribe(/active_record.sql/) do |_, _, _, _, hsh|
  ActiveRecord::Base.logger.info hsh[:sql]
end

require "factory_bot"
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].sort.each { |file| require file }

# Load base/generic schema
require test_dir.join("schema/version")
require test_dir.join("schema/generic_schema")

# Load the adapter's own schema if it has one (e.g. postgis), or else the schema for its
# database, so that e.g. trilogy and mysql2_makara get the mysql2 tables and spatialite the
# sqlite3 ones instead of relying on tables left behind by an earlier test run.
adapter_schema = test_dir.join("schema/#{adapter}_schema.rb")
unless adapter_schema.exist?
  case yaml_config["pool_adapter"] || yaml_config["adapter"]
  when /mysql|trilogy/ then adapter_schema = test_dir.join("schema/mysql2_schema.rb")
  when /postg/ then adapter_schema = test_dir.join("schema/postgresql_schema.rb")
  when /sqlite/ then adapter_schema = test_dir.join("schema/sqlite3_schema.rb")
  end
end
require adapter_schema if adapter_schema.exist?

Dir["#{File.dirname(__FILE__)}/models/*.rb"].sort.each { |file| require file }

# Prevent this deprecation warning from breaking the tests.
Rake::FileList.send(:remove_method, :import)

ActiveSupport::TestCase.test_order = :random
