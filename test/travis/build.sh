#!/bin/bash
# set -e
# set +x

function run {
  statement=$@
  logfile=$4.log
  $statement &> $logfile
  if [ $? != 0 ] ; then
    printf "AR_VERSION=$AR_VERSION $statement \e[31mFAILED\e[0m\n"
    cat $logfile
  else
    printf "AR_VERSION=$AR_VERSION $statement \e[32mPASSED\e[0m\n"
  fi
}

for activerecord_version in "3.1" "3.2" "4.0" "4.1" "4.2" "5.0" ; do
  export AR_VERSION=$activerecord_version

  bundle update activerecord > /dev/null

  run bundle exec rake test:mysql2                  # Run tests for mysql2
  run bundle exec rake test:mysql2spatial           # Run tests for mysql2spatial
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
