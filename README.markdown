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

The gem provides the following high-level features:

* activerecord-import can work with raw columns and arrays of values (fastest)
* activerecord-import works with model objects (faster)
* activerecord-import can perform validations (fast)
* activerecord-import can perform on duplicate key updates (requires MySQL or Postgres 9.5+)

## Table of Contents

* [Examples](#examples)
  * [Introduction](#introduction)
  * [Columns and Arrays](#columns-and-arrays)
  * [ActiveRecord Models](#activerecord-models)
  * [Batching](#batching)
  * [Recursive](#recursive)
* [Options](#options)
  * [Duplicate Key Ignore](#duplicate-key-ignore)
  * [Duplicate Key Update](#duplicate-key-update)
  * [Uniqueness Validation](#uniqueness-validation)
* [Array of Hashes](#array-of-hashes)
* [Counter Cache](#counter-cache)
* [ActiveRecord Timestamps](#activerecord-timestamps)
* [Callbacks](#callbacks)
* [Supported Adapters](#supported-adapters)
* [Additional Adapters](#additional-adapters)
* [Requiring](#requiring)
  * [Autoloading via Bundler](#autoloading-via-bundler)
  * [Manually Loading](#manually-loading)
* [Load Path Setup](#load-path-setup)
* [Conflicts With Other Gems](#conflicts-with-other-gems)
* [More Information](#more-information)
* [Contributing](#contributing)
  * [Running Tests](#running-tests)

### Examples

#### Introduction

Without `activerecord-import`, you'd write something like this:

```ruby
10.times do |i|
  Book.create! :name => "book #{i}"
end
```

This would end up making 10 SQL calls. YUCK!  With `activerecord-import`, you can instead do this:

```ruby
```ruby
books = []
10.times do |i|
  books << Book.new(:name => "book #{i}")
end
Book.import books    # or use import!
```

and only have 1 SQL call. Much better!

#### Columns and Arrays

The `import` method can take an array of column names (string or symbols) and an array of arrays. Each child array represents an individual record and its list of values in the same order as the columns. This is the fastest import mechanism and also the most primitive.

```ruby
columns = [ :title, :author ]
values = [ ['Book1', 'FooManChu'], ['Book2', 'Bob Jones'] ]

# Importing without model validations
Book.import columns, values, :validate => false

# Import with model validations
Book.import columns, values, :validate => true

# when not specified :validate defaults to true
Book.import columns, values
```

#### ActiveRecord Models

The `import` method can take an array of models. The attributes will be pulled off from each model by looking at the columns available on the model.

```ruby
books = [
  Book.new(:title => "Book 1", :author => "FooManChu"),
  Book.new(:title => "Book 2", :author => "Bob Jones")
]

# without validations
Book.import books, :validate => false

# with validations
Book.import books, :validate => true

# when not specified :validate defaults to true
Book.import books
```

The `import` method can take an array of column names and an array of models. The column names are used to determine what fields of data should be imported. The following example will only import books with the `title` field:

```ruby
books = [
  Book.new(:title => "Book 1", :author => "FooManChu"),
  Book.new(:title => "Book 2", :author => "Bob Jones")
]
columns = [ :title ]

# without validations
Book.import columns, books, :validate => false

# with validations
Book.import columns, books, :validate => true

# when not specified :validate defaults to true
Book.import columns, books

# result in table books
# title  | author
#--------|--------
# Book 1 | NULL
# Book 2 | NULL

```

#### Batching

The `import` method can take a `batch_size` option to control the number of rows to insert per INSERT statement. The default is the total number of records being inserted so there is a single INSERT statement.

```ruby
books = [
  Book.new(:title => "Book 1", :author => "FooManChu"),
  Book.new(:title => "Book 2", :author => "Bob Jones"),
  Book.new(:title => "Book 1", :author => "John Doe"),
  Book.new(:title => "Book 2", :author => "Richard Wright")
]
columns = [ :title ]

# 2 INSERT statements for 4 records
Book.import columns, books, :batch_size => 2
```

#### Recursive

NOTE: This only works with PostgreSQL.

Assume that Books <code>has_many</code> Reviews.

```ruby
books = []
10.times do |i|
  book = Book.new(:name => "book #{i}")
  book.reviews.build(:title => "Excellent")
  books << book
end
Book.import books, recursive: true
```

### Options

#### Duplicate Key Ignore

[MySQL](http://dev.mysql.com/doc/refman/5.0/en/insert-on-duplicate.html), [SQLite](https://www.sqlite.org/lang_insert.html), and [PostgreSQL](https://www.postgresql.org/docs/current/static/sql-insert.html#SQL-ON-CONFLICT) (9.5+) support `on_duplicate_key_ignore` which allows you to skip records if a primary or unique key constraint is violated.

```ruby
book = Book.create! title: "Book1", author: "FooManChu"
book.title = "Updated Book Title"
book.author = "Bob Barker"

Book.import [book], on_duplicate_key_ignore: true

book.reload.title  # => "Book1"     (stayed the same)
book.reload.author # => "FooManChu" (stayed the same)
```

The option `:on_duplicate_key_ignore` is bypassed when `:recursive` is enabled for [PostgreSQL imports](https://github.com/zdennis/activerecord-import/wiki#recursive-example-postgresql-only).

#### Duplicate Key Update

MySQL, PostgreSQL (9.5+), and SQLite (3.24.0+) support `on duplicate key update` (also known as "upsert") which allows you to specify fields whose values should be updated if a primary or unique key constraint is violated.

One big difference between MySQL and PostgreSQL support is that MySQL will handle any conflict that happens, but PostgreSQL requires that you specify which columns the conflict would occur over. SQLite models its upsert support after PostgreSQL.

Basic Update

```ruby
book = Book.create! title: "Book1", author: "FooManChu"
book.title = "Updated Book Title"
book.author = "Bob Barker"

# MySQL version
Book.import [book], on_duplicate_key_update: [:title]

# PostgreSQL version
Book.import [book], on_duplicate_key_update: {conflict_target: [:id], columns: [:title]}

# PostgreSQL shorthand version (conflict target must be primary key)
Book.import [book], on_duplicate_key_update: [:title]

book.reload.title  # => "Updated Book Title" (changed)
book.reload.author # => "FooManChu"          (stayed the same)
```

Using the value from another column

```ruby
book = Book.create! title: "Book1", author: "FooManChu"
book.title = "Updated Book Title"

# MySQL version
Book.import [book], on_duplicate_key_update: {author: :title}

# PostgreSQL version (no shorthand version)
Book.import [book], on_duplicate_key_update: {
  conflict_target: [:id], columns: {author: :title}
}

book.reload.title  # => "Book1"              (stayed the same)
book.reload.author # => "Updated Book Title" (changed)
```

Using Custom SQL

```ruby
book = Book.create! title: "Book1", author: "FooManChu"
book.author = "Bob Barker"

# MySQL version
Book.import [book], on_duplicate_key_update: "author = values(author)"

# PostgreSQL version
Book.import [book], on_duplicate_key_update: {
  conflict_target: [:id], columns: "author = excluded.author"
}

# PostgreSQL shorthand version (conflict target must be primary key)
Book.import [book], on_duplicate_key_update: "author = excluded.author"

book.reload.title  # => "Book1"      (stayed the same)
book.reload.author # => "Bob Barker" (changed)
```

PostgreSQL Using constraints

```ruby
book = Book.create! title: "Book1", author: "FooManChu", edition: 3, published_at: nil
book.published_at = Time.now

# in migration
execute <<-SQL
      ALTER TABLE books
        ADD CONSTRAINT for_upsert UNIQUE (title, author, edition);
    SQL

# PostgreSQL version
Book.import [book], on_duplicate_key_update: {constraint_name: :for_upsert, columns: [:published_at]}


book.reload.title  # => "Book1"          (stayed the same)
book.reload.author # => "FooManChu"      (stayed the same)
book.reload.edition # => 3               (stayed the same)
book.reload.published_at # => 2017-10-09 (changed)
```

#### Uniqueness Validation

By default, `activerecord-import` will not validate for uniquness when importing records. Starting with `v0.27.0`, there is a  parameter called `validate_uniqueness` that can be passed in to trigger this behavior. This option is provided with caution as there are many potential pitfalls. Please use with caution.

```ruby
Book.import books, validate_uniqueness: true
```

### Array of Hashes

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

### Counter Cache

When running `import`, `activerecord-import` does not automatically update counter cache columns. To update these columns, you will need to do one of the following:

* Provide values to the column as an argument on your object that is passed in.
* Manually update the column after the record has been imported.

### ActiveRecord Timestamps

If you're familiar with ActiveRecord you're probably familiar with its timestamp columns: created_at, created_on, updated_at, updated_on, etc. When importing data the timestamp fields will continue to work as expected and each timestamp column will be set.

Should you wish to specify those columns, you may use the option `timestamps: false`.

However, it is also possible to set just `:created_at` in specific records. In this case despite using `timestamps: true`,  `:created_at` will be updated only in records where that field is `nil`. Same rule applies for record associations when enabling the option `recursive: true`.

If you are using custom time zones, these will be respected when performing imports as well as long as `ActiveRecord::Base.default_timezone` is set, which for practically all Rails apps it is

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

### Supported Adapters

The following database adapters are currently supported:

* MySQL - supports core import functionality plus on duplicate key update support (included in activerecord-import 0.1.0 and higher)
* MySQL2 - supports core import functionality plus on duplicate key update support (included in activerecord-import 0.2.0 and higher)
* PostgreSQL - supports core import functionality (included in activerecord-import 0.1.0 and higher)
* SQLite3 - supports core import functionality (included in activerecord-import 0.1.0 and higher)
* Oracle - supports core import functionality through DML trigger (available as an external gem: [activerecord-import-oracle_enhanced](https://github.com/keeguon/activerecord-import-oracle_enhanced)
* SQL Server - supports core import functionality (available as an external gem: [activerecord-import-sqlserver](https://github.com/keeguon/activerecord-import-sqlserver)

If your adapter isn't listed here, please consider creating an external gem as described in the README to provide support. If you do, feel free to update this wiki to include a link to the new adapter's repository!

To test which features are supported by your adapter, use the following methods on a model class:
* `supports_import?(*args)`
* `supports_on_duplicate_key_update?`
* `supports_setting_primary_key_of_imported_objects?`

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
