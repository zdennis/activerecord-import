# activerecord-import

activerecord-import is a library for bulk inserting data using ActiveRecord.

### Rails 4.0

Use activerecord-import 0.4.0 or higher.

### Rails 3.1.x up to, but not including 4.0

Use the latest in the activerecord-import 0.3.x series.

### Rails 3.0.x up to, but not including 3.1

Use activerecord-import 0.2.11. As of activerecord-import 0.3.0 we are relying on functionality that was introduced in Rails 3.1. Since Rails 3.0.x is no longer a supported version of Rails we have decided to drop support as well.

### For More Information

For more information on activerecord-import please see its wiki: https://github.com/zdennis/activerecord-import/wiki

## Additional Adapters
Additional adapters can be provided by gems external to activerecord-import by providing an adapter that matches the naming convention setup by activerecord-import (and subsequently activerecord) for dynamically loading adapters.  This involves also providing a folder on the load path that follows the activerecord-import naming convention to allow activerecord-import to dynamically load the file.

When `ActiveRecord::Import.require_adapter("fake_name")` is called the require will be:

```ruby
  require 'activerecord-import/active_record/adapters/fake_name_adapter'
```

This allows an external gem to dyanmically add an adapter without the need to add any file/code to the core activerecord-import gem.

### Load Path Setup
To understand how rubygems loads code you can reference the following:

  http://guides.rubygems.org/patterns/#loading_code

And an example of how active_record dynamically load adapters:
  https://github.com/rails/rails/blob/master/activerecord/lib/active_record/connection_adapters/connection_specification.rb 

In summary, when a gem is loaded rubygems adds the `lib` folder of the gem to the global load path `$LOAD_PATH` so that all `require` lookups will not propegate through all of the folders on the load path. When a `require` is issued each folder on the `$LOAD_PATH` is checked for the file and/or folder referenced. This allows a gem (like activerecord-import) to define push the activerecord-import folder (or namespace) on the `$LOAD_PATH` and any adapters provided by activerecord-import will be found by rubygems when the require is issued.

If `fake_name` adapter is needed by a gem (potentially called `activerecord-import-fake_name`) then the folder structure should look as follows:

```bash
activerecord-import-fake_name/
|-- activerecord-import-fake_name.gemspec
|-- lib
|   |-- activerecord-import-fake_name
|   |   |-- version.rb
|   |-- activerecord-import
|   |   |-- active_record
|   |   |   |-- adapters
|   |   |       |-- fake_name_adapter.rb
|--activerecord-import-fake_name.rb
```

When rubygems pushes the `lib` folder onto the load path a `require` will now find `activerecord-import/active_record/adapters/fake_name_adapter` as it runs through the lookup process for a ruby file under that path in `$LOAD_PATH`

# License

This is licensed under the ruby license. 

# Author

Zach Dennis (zach.dennis@gmail.com)

# Contributors

* Blythe Dunham
* Gabe da Silveira
* Henry Work
* James Herdman
* Marcus Crafter
* Thibaud Guillaume-Gentil
* Mark Van Holstyn 
* Victor Costan
