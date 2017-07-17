# activerecord-import [![Build Status](https://travis-ci.org/zdennis/activerecord-import.svg?branch=master)](https://travis-ci.org/zdennis/activerecord-import)

activerecord-import is a library for bulk inserting data using ActiveRecord.

One of its major features is following activerecord associations and generating the minimal
number of SQL insert statements required, avoiding the N+1 insert problem. An example probably
explains it best. Say you had a schema like this:

- Publishers have Books
- Books have Reviews

and you wanted to bulk insert 100 new publishers with 10K books and 3 reviews per book. This library will follow the associations
down and generate only 3 SQL insert statements - one for the publishers, one for the books, and one for the reviews.

In contrast, the standard ActiveRecord save would generate
100 insert statements for the publishers, then it would visit each publisher and save all the books:
100 * 10,000 = 1,000,000 SQL insert statements
and then the reviews:
100 * 10,000 * 3 = 3M SQL insert statements,

That would be about 4M SQL insert statements vs 3, which results in vastly improved performance. In our case, it converted
an 18 hour batch process to <2 hrs.

### More Information : Usage and Examples in Wiki

For more information on activerecord-import please see its wiki: https://github.com/zdennis/activerecord-import/wiki

## Additional Adapters
Additional adapters can be provided by gems external to activerecord-import by providing an adapter that matches the naming convention setup by activerecord-import (and subsequently activerecord) for dynamically loading adapters.  This involves also providing a folder on the load path that follows the activerecord-import naming convention to allow activerecord-import to dynamically load the file.

When `ActiveRecord::Import.require_adapter("fake_name")` is called the require will be:

```ruby
  require 'activerecord-import/active_record/adapters/fake_name_adapter'
```

This allows an external gem to dynamically add an adapter without the need to add any file/code to the core activerecord-import gem.

### Load Path Setup
To understand how rubygems loads code you can reference the following:

  http://guides.rubygems.org/patterns/#loading_code

And an example of how active_record dynamically load adapters:
  https://github.com/rails/rails/blob/master/activerecord/lib/active_record/connection_adapters/connection_specification.rb

In summary, when a gem is loaded rubygems adds the `lib` folder of the gem to the global load path `$LOAD_PATH` so that all `require` lookups will not propagate through all of the folders on the load path. When a `require` is issued each folder on the `$LOAD_PATH` is checked for the file and/or folder referenced. This allows a gem (like activerecord-import) to define push the activerecord-import folder (or namespace) on the `$LOAD_PATH` and any adapters provided by activerecord-import will be found by rubygems when the require is issued.

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

* Jordan Owens (@jkowens)
* Erik Michaels-Ober (@sferik)
* Blythe Dunham
* Gabe da Silveira
* Henry Work
* James Herdman
* Marcus Crafter
* Sai (@saizai)
* Thibaud Guillaume-Gentil
* Mark Van Holstyn
* Victor Costan
