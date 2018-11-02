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

* [Array of Hashes](#array-of-hashes)
* [Uniqueness Validation](#uniqueness-validation)
* [Counter Cache](#counter-cache)
* [ActiveRecord Timestamps](#activerecord-timestamps)
* [Callbacks](#callbacks)
* [Additional Adapters](#additional-adapters)
* [Requiring](#requiring)
  * [Autoloading via Bundler](#autoloading-via-bundler)
  * [Manually Loading](#manually-loading)
* [Load Path Setup](#load-path-setup)
* [Conflicts With Other Gems](#conflicts-with-other-gems)
* [More Information](#more-information)
* [Contributing](#contributing)
  * [Running Tests](#running-tests)

## Array of Hashes

Due to the counter-intuitive behavior that can occur when dealing with hashes instead of ActiveRecord objects, `activerecord-import` will raise an exception when passed an array of hashes. If you have an array of hash attributes, you should instead use them to instantiate an array of ActiveRecord objects and then pass that into `import`.

See https://github.com/zdennis/activerecord-import/issues/507 for discussion.

```ruby
arr = [
  { bar: 'abc' },
  { baz: 'xyz' },
  { bar: '123', baz: '456' }
]

# An exception will be raised
Foo.import arr

# better
arr.map! { |args| Foo.new(args) }
Foo.import arr
```

### Uniqueness Validation

By default, `activerecord-import` will not validate for uniquness when importing records. Starting with `v0.27.0`, there is a  parameter called `validate_uniqueness` that can be passed in to trigger this behavior. This option is provided with caution as there are many potential pitfalls. Please use with caution.

```ruby
Book.import books, validate_uniqueness: true
```

### Counter Cache

When running `import`, `activerecord-import` does not automatically update counter cache columns. To update these columns, you will need to do one of the following:

* Provide values to the column as an argument on your object that is passed in.
* Manually update the column after the record has been imported.

### ActiveRecord Timestamps

If you're familiar with ActiveRecord you're probably familiar with its timestamp columns: created_at, created_on, updated_at, updated_on, etc. When importing data the timestamp fields will continue to work as expected and each timestamp column will be set.

Should you wish to specify those columns, you may use the option @timestamps: false@.

However, it is also possible to set just @:created_at@ in specific records. In this case despite using @timestamps: true@,  @:created_at@ will be updated only in records where that field is @nil@. Same rule applies for record associations when enabling the option @recursive: true@.

If you are using custom time zones, these will be respected when performing imports as well as long as @ActiveRecord::Base.default_timezone@ is set, which for practically all Rails apps it is

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

### Requiring

Note: These instructions will only work if you are using version 0.2.0 or higher.

#### Autoloading via Bundler

If you are using Rails or otherwise autoload your dependencies via Bundler, all you need to do add the gem to your `Gemfile` like so:

```ruby
gem 'activerecord-import'
```

#### Manually Loading

You may want to manually load activerecord-import for one reason or another. First, add the `require: false` argument like so:

```ruby
 gem 'activerecord-import', require: false
 ```

This will allow you to load up activerecord-import in the file or files where you are using it and only load the parts you need.
If you are doing this within Rails and ActiveRecord has established a database connection (such as within a controller), you will need to do extra initialization work:

```ruby
require 'activerecord-import/base'
# load the appropriate database adapter (postgresql, mysql2, sqlite3, etc)
require 'activerecord-import/active_record/adapters/postgresql_adapter'
```

If your gem dependencies aren’t autoloaded, and your script will be establishing a database connection, then simply require activerecord-import after ActiveRecord has been loaded, i.e.:

```ruby
require 'active_record'
require 'activerecord-import'
```

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


### Conflicts With Other Gems

`activerecord-import` adds the `.import` method onto `ActiveRecord::Base`. There are other gems, such as `elasticsearch-rails`, that do the same thing. In conflicts such as this, there is an aliased method named `.bulk_import` that can be used interchangeably.

If you are using the `apartment` gem, there is a weird triple interaction between that gem, `activerecord-import`, and `activerecord` involving caching of the `sequence_name` of a model. This can be worked around by explcitly setting this value within the model. For example:

```ruby
class Post < ActiveRecord::Base
  self.sequence_name = "posts_seq"
end
```

Another way to work around the issue is to call `.reset_sequence_name` on the model. For example:

```ruby
schemas.all.each do |schema|
  Apartment::Tenant.switch! schema.name
  ActiveRecord::Base.transaction do
    Post.reset_sequence_name

    Post.import posts
  end
end
```

See https://github.com/zdennis/activerecord-import/issues/233 for further discussion.

### More Information

For more information on activerecord-import please see its wiki: https://github.com/zdennis/activerecord-import/wiki

To document new information, please add to the README instead of the wiki. See https://github.com/zdennis/activerecord-import/issues/397 for discussion.

### Contributing

#### Running Tests

The first thing you need to do is set up your database(s):

* copy `test/database.yml.sample` to `test/database.yml`
* modify `test/database.yml` for your database settings
* create databases as needed

After that, you can run the tests. They run against multiple tests and ActiveRecord versions.

This is one example of how to run the tests:

```ruby
rm Gemfile.lock
AR_VERSION=4.2 bundle install
AR_VERSION=4.2 bundle exec rake test:postgresql test:sqlite3 test:mysql2
```

Once you have pushed up your changes, you can find your CI results [here](https://travis-ci.org/zdennis/activerecord-import/).

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
