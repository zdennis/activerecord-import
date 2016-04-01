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
