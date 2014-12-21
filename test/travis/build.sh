#!/bin/bash
set -e
set +x

function run {
  echo "Running: AR_VERSION=$AR_VERSION $@"
  $@
}

for activerecord_version in "3.1" "3.2" "4.1" "4.2" ; do
  export AR_VERSION=$activerecord_version

  bundle update activerecord

  run run bundle exec rake test:em_mysql2               # Run tests for em_mysql2
  run bundle exec rake test:mysql                   # Run tests for mysql
  run bundle exec rake test:mysql2                  # Run tests for mysql2
  run bundle exec rake test:mysql2spatial           # Run tests for mysql2spatial
  run bundle exec rake test:mysqlspatial            # Run tests for mysqlspatial
  run bundle exec rake test:postgis                 # Run tests for postgis
  run bundle exec rake test:postgresql              # Run tests for postgresql
  run bundle exec rake test:seamless_database_pool  # Run tests for seamless_database_pool
  run bundle exec rake test:spatialite              # Run tests for spatialite
  # so far the version installed in travis seems < 3.7.11 so we cannot test sqlite3 on it
  # run bundle exec rake test:sqlite3

  #jruby
  #bundle exec rake test:jdbcmysql               # Run tests for jdbcmysql
  #bundle exec rake test:jdbcpostgresql          # Run tests for jdbcpostgresql
done
