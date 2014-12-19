#!/bin/sh
set -e
set +x

bundle exec rake test:em_mysql2               # Run tests for em_mysql2
bundle exec rake test:mysql                   # Run tests for mysql
bundle exec rake test:mysql2                  # Run tests for mysql2
bundle exec rake test:mysql2spatial           # Run tests for mysql2spatial
bundle exec rake test:mysqlspatial            # Run tests for mysqlspatial
bundle exec rake test:postgis                 # Run tests for postgis
bundle exec rake test:postgresql              # Run tests for postgresql
bundle exec rake test:seamless_database_pool  # Run tests for seamless_database_pool
bundle exec rake test:spatialite              # Run tests for spatialite
# so far the version installed in travis seems < 3.7.11 so we cannot test sqlite3 on it
# bundle exec rake test:sqlite3

#jruby
#bundle exec rake test:jdbcmysql               # Run tests for jdbcmysql
#bundle exec rake test:jdbcpostgresql          # Run tests for jdbcpostgresql

export AR_VERSION=4.1
bundle update activerecord
bundle exec rake test:em_mysql2               # Run tests for em_mysql2
bundle exec rake test:mysql                   # Run tests for mysql
bundle exec rake test:mysql2                  # Run tests for mysql2
bundle exec rake test:mysql2spatial           # Run tests for mysql2spatial
bundle exec rake test:mysqlspatial            # Run tests for mysqlspatial
bundle exec rake test:postgis                 # Run tests for postgis
bundle exec rake test:postgresql              # Run tests for postgresql
bundle exec rake test:seamless_database_pool  # Run tests for seamless_database_pool
bundle exec rake test:spatialite              # Run tests for spatialite
