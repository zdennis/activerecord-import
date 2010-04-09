# activerecord-import

activerecord-import is a library for bulk inserting data using ActiveRecord. By default with ActiveRecord, in order to insert multiple records you have to perform individual save operations on each model, like so:

    10.times do |i|
      Book.create! :name => "book #{i}"
    end
    
This may work fine if all you have is 10 records, but if you have hundreds, thousands, or millions of records it can turn into a nightmare. This is where activerecord-import comes into play. Here's the equivalent behaviour using the #import method:

    books = []
    10.times{ |i| books << Book.new(:name => "book #{i}") }
    Book.import books
    
Pretty slick, eh? 

Maybe, just maybe you're thinking, why do I have do instantiate ActiveRecord objects? Will that perform validations? What if I don't want validations? What if I want to take advantage of features like MySQL's on duplicate key update? Well, activerecord-import handles all of these cases and more! 

For more documentation on the matter you can refer to two places:

1. activerecord-import github wiki: http://wiki.github.com/zdennis/activerecord-import/
1. the tests in the code base

Note: the tests have been updated since the previous version of ar-extensions to provide better readability and easier maintenance.

# LICENSE

This is licensed under the ruby license. 

# Author

Zach Dennis (zach.dennis@gmail.com)

# Contributor

* Blythe Dunham
* Gabe da Silveira
* Henry Work
* James Herdman
* Marcus Crafter
* Thibaud Guillaume-Gentil
* Mark Van Holstyn 
