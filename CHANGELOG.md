## Changes in 0.16.0

### New Features

* Add partial index upsert support for PostgreSQL. Thanks to @luislew via \#305
* Add UUID primary key support for PostgreSQL. Thanks to @jkowens via
  \#312
* Add store accessor support for JSON, JSON, and HSTORE data types.
  Thanks to @jkowens via \#322
* Log warning if database does not support :on_duplicate_key_update.
  Thanks to @jkowens vi \#324
* Add option :on_duplicate_key_ignore for MySQL and SQLite. Thanks to
  @jkowens via \#326

### Fixes

* Fixes issue with recursive import using same primary key for all models.
  Thanks to @chopraanmol1 via \#309
* Fixes issue importing from STI subclass with polymorphic associations.
  Thanks to @JNajera via \#314
* Fixes issue setting returned IDs to wrong models when some fail validation. Also fixes issue with SQLite returning wrong IDs. Thanks to @mizukami234 via \#315


## Changes in 0.15.0

### New Features

* An ArgumentError is now raised if when no `conflict_target` or `conflict_name` is provided or can be determined when using the `on_duplicate_key_update` option for PostgreSQL. Thanks to @jkowens via \#290
* Support for Rails 5.0 final release for all except the JDBC driver which is not yet updated to support Rails 5.0

### Fixes

* activerecord-import no longer modifies a value array inside of the given values array when called with `import(columns, values)`. Thanks to @jkowens via \#291

### Misc

* `raise_error` is used to raise errors for ActiveRecord 5.0. Thanks to @couragecourag via \#294 `raise_record_invalid` has been


## Changes in 0.14.1

### Fixes

* JRuby/JDBCDriver with PostgreSQL will no longer raise a JDBCDriver error when using the :no_returning boolean option. Thanks to @jkowens via \#287

## Changes in 0.14.0

### New Features

* Support for ActiveRecord 3.1 has been dropped. Thanks to @sferik via \#254
* SQLite3 has learned the :recursive option. Thanks to @jkowens via \#281
* :on_duplicate_key_ignore will be ignored when imports are being done with :recursive. Thanks to @jkowens via \#268
* :activerecord-import learned how to tell PostgreSQL to return no data back from the import via the :no_returning boolean option. Thanks to @makaroni4 via \#276

### Fixes

* Polymorphic associations will not import the :type column. Thanks to @seanlinsley via \#282 and \#283
* ~2X speed increase for importing models with validations. Thanks to @jkowens via \#266

### Misc

* Benchmark HTML report has been fixed. Thanks to @jkowens via \#264
* seamless_database_pool has been updated to work with AR 5.0. Thanks to @jkowens via \#280
* Code cleanup, removal of redundant condition checks. Thanks to @pavlik4k via \#273
* Code cleanup, removal of deprecated `alias_method_chain`. Thanks to @codeodor via \#271


## Changes in 0.13.0

### New Features

* Addition of :batch_size option to control the number of rows to insert per INSERT statement. The default is the total number of records being inserted so there is a single INSERT statement. Thanks to @jkowens via \#245

* Addition `import!` which will raise an exception if a validation occurs. It will fail fast. Thanks to @jkowens via \#246

### Fixes

* Fixing issue with recursive import when utilizing the `:on_duplicate_key_update` option. The `on_duplicate_key_update` only applies to parent models at this time. Thanks to @yuri-karpovich for reporting and  @jkowens for fixing via \#249

### Misc

* Refactoring of fetching and assigning attributes. Thanks to @jkownes via \#259
* Lots of code cleanup and addition of Rubocop linter. Thanks to @sferik via \#256 and \#250
* Resolving errors with the test suite when running against ActiveRecord 4.0 and 4.1. Thanks to @jkowens via \#262
* Cleaning up the TravisCI settings and packages. Thanks to @sferik via \#258 and \#251

## Changes in 0.12.0

### New Features

* PostgreSQL UPSERT support has been added. Thanks @jkowens via \#218

### Fixes

* has_one and has_many associations will now be recursively imported regardless of :autosave being set. Thanks @sferik, @jkowens via \#243, \#234
* Fixing an issue with enum column support for Rails > 4.1. Thanks @aquajach via \#235

### Removals

* Support for em-synchrony has been removed since it appears the project has been abandoned. Thanks @sferik, @zdennis via \#239
* Support for the mysql gem/adapter has been removed since it has officially been abandoned. Use the mysql2 gem/adapter instead. Thanks @sferik, @zdennis via \#239

### Misc

* Cleaned up TravisCI output and removing deprecation warnings. Thanks @jkowens, @zdennis \#242


## Changes before 0.12.0

> Never look back. What's gone is now history. But in the process make memory of events to help you understand what will help you to make your dream a true story. Mistakes of the past are lessons, success of the past is inspiration. – Dr. Anil Kr Sinha
