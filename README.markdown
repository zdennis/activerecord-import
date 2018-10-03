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

## Table of Contents

* [Callbacks](#callbacks)
* [Additional Adapters](#additional-adapters)
* [Load Path Setup](#load-path-setup)
* [More Information](#more-information)

### Callbacks

ActiveRecord callbacks related to [creating](http://guides.rubyonrails.org/active_record_callbacks.html#creating-an-object), [updating](http://guides.rubyonrails.org/active_record_callbacks.html#updating-an-object), or [destroying](http://guides.rubyonrails.org/active_record_callbacks.html#destroying-an-object) records (other than `before_validation` and `after_validation`) will NOT be called when calling the import method. This is because it is mass importing rows of data and doesn't necessarily have access to in-memory ActiveRecord objects.

If you do have a collection of in-memory ActiveRecord objects you can do something like this:

```
books.each do |book|
  book.run_callbacks(:save) { false }
  book.run_callbacks(:create) { false }
end
Book.import(books)
```

This will run before_create and before_save callbacks on each item. The `false` argument is needed to prevent after_save being run, which wouldn't make sense prior to bulk import. Something to note in this example is that the before_create and before_save callbacks will run before the validation callbacks.

If that is an issue, another possible approach is to loop through your models first to do validations and then only run callbacks on and import the valid models.

```
valid_books = []
invalid_books = []

books.each do |book|
  if book.valid?
    valid_books << book
  else
    invalid_books << book
  end
end

valid_books.each do |book|
  book.run_callbacks(:save) { false }
  book.run_callbacks(:create) { false }
end

Book.import valid_books, validate: false
```

### Additional Adapters

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
|   |-- activerecord-import-fake_name.rb
|   |-- activerecord-import-fake_name
|   |   |-- version.rb
|   |-- activerecord-import
|   |   |-- active_record
|   |   |   |-- adapters
|   |   |       |-- fake_name_adapter.rb
```

When rubygems pushes the `lib` folder onto the load path a `require` will now find `activerecord-import/active_record/adapters/fake_name_adapter` as it runs through the lookup process for a ruby file under that path in `$LOAD_PATH`

### More Information

For more information on activerecord-import please see its wiki: https://github.com/zdennis/activerecord-import/wiki

To document new information, please add to the README instead of the wiki. See https://github.com/zdennis/activerecord-import/issues/397 for discussion.

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
* Thibaud Guillaume-Gentil
* Mark Van Holstyn
* Victor Costan
