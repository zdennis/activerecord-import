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
