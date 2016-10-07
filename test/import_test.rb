require File.expand_path('../test_helper', __FILE__)

describe "#import" do
  it "should return the number of inserts performed" do
    # see ActiveRecord::ConnectionAdapters::AbstractAdapter test for more specifics
    assert_difference "Topic.count", +10 do
      result = Topic.import Build(3, :topics)
      assert result.num_inserts > 0

      result = Topic.import Build(7, :topics)
      assert result.num_inserts > 0
    end
  end

  it "should not produce an error when importing empty arrays" do
    assert_nothing_raised do
      Topic.import []
      Topic.import %w(title author_name), []
    end
  end

  describe "argument safety" do
    it "should not modify the passed in columns array" do
      assert_nothing_raised do
        columns = %w(title author_name).freeze
        Topic.import columns, [%w(foo bar)]
      end
    end

    it "should not modify the passed in values array" do
      assert_nothing_raised do
        record = %w(foo bar).freeze
        values = [record].freeze
        Topic.import %w(title author_name), values
      end
    end
  end

  describe "with non-default ActiveRecord models" do
    context "that have a non-standard primary key (that is no sequence)" do
      it "should import models successfully" do
        assert_difference "Widget.count", +3 do
          Widget.import Build(3, :widgets)
        end
      end
    end

    context "that have no primary key" do
      it "should import models successfully" do
        assert_difference "Rule.count", +3 do
          Rule.import Build(3, :rules)
        end
      end
    end
  end

  describe "with STI models" do
    it "should import models successfully" do
      dictionaries = [Dictionary.new(author_name: "Noah Webster", title: "Webster's Dictionary")]

      assert_difference "Dictionary.count", +1 do
        Dictionary.import dictionaries
      end
      assert_equal "Dictionary", Dictionary.first.type
    end
  end

  context "with :validation option" do
    let(:columns) { %w(title author_name) }
    let(:valid_values) { [["LDAP", "Jerry Carter"], ["Rails Recipes", "Chad Fowler"]] }
    let(:valid_values_with_context) { [[1111, "Jerry Carter"], [2222, "Chad Fowler"]] }
    let(:invalid_values) { [["The RSpec Book", ""], ["Agile+UX", ""]] }
    let(:valid_models) { valid_values.map { |title, author_name| Topic.new(title: title, author_name: author_name) } }
    let(:invalid_models) { invalid_values.map { |title, author_name| Topic.new(title: title, author_name: author_name) } }

    context "with validation checks turned off" do
      it "should import valid data" do
        assert_difference "Topic.count", +2 do
          Topic.import columns, valid_values, validate: false
        end
      end

      it "should import invalid data" do
        assert_difference "Topic.count", +2 do
          Topic.import columns, invalid_values, validate: false
        end
      end

      it 'should raise a specific error if a column does not exist' do
        assert_raises ActiveRecord::Import::MissingColumnError do
          Topic.import ['foo'], [['bar']], validate: false
        end
      end
    end

    context "with validation checks turned on" do
      it "should import valid data" do
        assert_difference "Topic.count", +2 do
          Topic.import columns, valid_values, validate: true
        end
      end

      it "should import valid data with on option" do
        assert_difference "Topic.count", +2 do
          Topic.import columns, valid_values_with_context, validate_with_context: :context_test
        end
      end

      it "should not import invalid data" do
        assert_no_difference "Topic.count" do
          Topic.import columns, invalid_values, validate: true
        end
      end

      it "should import invalid data with on option" do
        assert_no_difference "Topic.count" do
          Topic.import columns, valid_values, validate_with_context: :context_test
        end
      end

      it "should report the failed instances" do
        results = Topic.import columns, invalid_values, validate: true
        assert_equal invalid_values.size, results.failed_instances.size
        results.failed_instances.each { |e| assert_kind_of Topic, e }
      end

      it "should set ids in valid models if adapter supports setting primary key of imported objects" do
        if ActiveRecord::Base.support_setting_primary_key_of_imported_objects?
          Topic.import (invalid_models + valid_models), validate: true
          assert_nil invalid_models[0].id
          assert_nil invalid_models[1].id
          assert_equal valid_models[0].id, Topic.all[0].id
          assert_equal valid_models[1].id, Topic.all[1].id
        end
      end

      it "should import valid data when mixed with invalid data" do
        assert_difference "Topic.count", +2 do
          Topic.import columns, valid_values + invalid_values, validate: true
        end
        assert_equal 0, Topic.where(title: invalid_values.map(&:first)).count
      end
    end
  end

  context "without :validation option" do
    let(:columns) { %w(title author_name) }
    let(:invalid_values) { [["The RSpec Book", ""], ["Agile+UX", ""]] }

    it "should not import invalid data" do
      assert_no_difference "Topic.count" do
        result = Topic.import columns, invalid_values
        assert_equal 2, result.failed_instances.size
      end
    end
  end

  context "with :all_or_none option" do
    let(:columns) { %w(title author_name) }
    let(:valid_values) { [["LDAP", "Jerry Carter"], ["Rails Recipes", "Chad Fowler"]] }
    let(:invalid_values) { [["The RSpec Book", ""], ["Agile+UX", ""]] }
    let(:mixed_values) { valid_values + invalid_values }

    context "with validation checks turned on" do
      it "should import valid data" do
        assert_difference "Topic.count", +2 do
          Topic.import columns, valid_values, all_or_none: true
        end
      end

      it "should not import invalid data" do
        assert_no_difference "Topic.count" do
          Topic.import columns, invalid_values, all_or_none: true
        end
      end

      it "should not import valid data when mixed with invalid data" do
        assert_no_difference "Topic.count" do
          Topic.import columns, mixed_values, all_or_none: true
        end
      end

      it "should report the failed instances" do
        results = Topic.import columns, mixed_values, all_or_none: true
        assert_equal invalid_values.size, results.failed_instances.size
        results.failed_instances.each { |e| assert_kind_of Topic, e }
      end

      it "should report the zero inserts" do
        results = Topic.import columns, mixed_values, all_or_none: true
        assert_equal 0, results.num_inserts
      end
    end
  end

  context "with :batch_size option" do
    it "should import with a single insert" do
      assert_difference "Topic.count", +10 do
        result = Topic.import Build(10, :topics), batch_size: 10
        assert_equal 1, result.num_inserts if Topic.supports_import?
      end
    end

    it "should import with multiple inserts" do
      assert_difference "Topic.count", +10 do
        result = Topic.import Build(10, :topics), batch_size: 4
        assert_equal 3, result.num_inserts if Topic.supports_import?
      end
    end
  end

  context "with :synchronize option" do
    context "synchronizing on new records" do
      let(:new_topics) { Build(3, :topics) }

      it "doesn't reload any data (doesn't work)" do
        Topic.import new_topics, synchronize: new_topics
        if Topic.support_setting_primary_key_of_imported_objects?
          assert new_topics.all?(&:persisted?), "Records should have been reloaded"
        else
          assert new_topics.all?(&:new_record?), "No record should have been reloaded"
        end
      end
    end

    context "synchronizing on new records with explicit conditions" do
      let(:new_topics) { Build(3, :topics) }

      it "reloads data for existing in-memory instances" do
        Topic.import(new_topics, synchronize: new_topics, synchronize_keys: [:title] )
        assert new_topics.all?(&:persisted?), "Records should have been reloaded"
      end
    end

    context "synchronizing on destroyed records with explicit conditions" do
      let(:new_topics) { Generate(3, :topics) }

      it "reloads data for existing in-memory instances" do
        new_topics.each(&:destroy)
        Topic.import(new_topics, synchronize: new_topics, synchronize_keys: [:title] )
        assert new_topics.all?(&:persisted?), "Records should have been reloaded"
      end
    end
  end

  context "with an array of unsaved model instances" do
    let(:topic) { Build(:topic, title: "The RSpec Book", author_name: "David Chelimsky") }
    let(:topics) { Build(9, :topics) }
    let(:invalid_topics) { Build(7, :invalid_topics) }

    it "should import records based on those model's attributes" do
      assert_difference "Topic.count", +9 do
        Topic.import topics
      end

      Topic.import [topic]
      assert Topic.where(title: "The RSpec Book", author_name: "David Chelimsky").first
    end

    it "should not overwrite existing records" do
      topic = Generate(:topic, title: "foobar")
      assert_no_difference "Topic.count" do
        begin
          Topic.transaction do
            topic.title = "baz"
            Topic.import [topic]
          end
        rescue Exception
          # PostgreSQL raises PgError due to key constraints
          # I don't know why ActiveRecord doesn't catch these. *sigh*
        end
      end
      assert_equal "foobar", topic.reload.title
    end

    context "with validation checks turned on" do
      it "should import valid models" do
        assert_difference "Topic.count", +9 do
          Topic.import topics, validate: true
        end
      end

      it "should not import invalid models" do
        assert_no_difference "Topic.count" do
          Topic.import invalid_topics, validate: true
        end
      end
    end

    context "with validation checks turned off" do
      it "should import invalid models" do
        assert_difference "Topic.count", +7 do
          Topic.import invalid_topics, validate: false
        end
      end
    end
  end

  context "with an array of columns and an array of unsaved model instances" do
    let(:topics) { Build(2, :topics) }

    it "should import records populating the supplied columns with the corresponding model instance attributes" do
      assert_difference "Topic.count", +2 do
        Topic.import [:author_name, :title], topics
      end

      # imported topics should be findable by their imported attributes
      assert Topic.where(author_name: topics.first.author_name).first
      assert Topic.where(author_name: topics.last.author_name).first
    end

    it "should not populate fields for columns not imported" do
      topics.first.author_email_address = "zach.dennis@gmail.com"
      assert_difference "Topic.count", +2 do
        Topic.import [:author_name, :title], topics
      end

      assert !Topic.where(author_email_address: "zach.dennis@gmail.com").first
    end
  end

  context "with an array of columns and an array of values" do
    it "should import ids when specified" do
      Topic.import [:id, :author_name, :title], [[99, "Bob Jones", "Topic 99"]]
      assert_equal 99, Topic.last.id
    end

    it "ignores the recursive option" do
      assert_difference "Topic.count", +1 do
        Topic.import [:author_name, :title], [["David Chelimsky", "The RSpec Book"]], recursive: true
      end
    end
  end

  context "ActiveRecord timestamps" do
    let(:time) { Chronic.parse("5 minutes ago") }

    context "when the timestamps columns are present" do
      setup do
        @existing_book = Book.create(title: "Fell", author_name: "Curry", publisher: "Bayer", created_at: 2.years.ago.utc, created_on: 2.years.ago.utc)
        ActiveRecord::Base.default_timezone = :utc
        Timecop.freeze(time) do
          assert_difference "Book.count", +2 do
            Book.import %w(title author_name publisher created_at created_on), [["LDAP", "Big Bird", "Del Rey", nil, nil], [@existing_book.title, @existing_book.author_name, @existing_book.publisher, @existing_book.created_at, @existing_book.created_on]]
          end
        end
        @new_book, @existing_book = Book.last 2
      end

      it "should set the created_at column for new records" do
        assert_in_delta time.to_i, @new_book.created_at.to_i, 1.second
      end

      it "should set the created_on column for new records" do
        assert_in_delta time.to_i, @new_book.created_on.to_i, 1.second
      end

      it "should not set the created_at column for existing records" do
        assert_equal 2.years.ago.utc.strftime("%Y:%d"), @existing_book.created_at.strftime("%Y:%d")
      end

      it "should not set the created_on column for existing records" do
        assert_equal 2.years.ago.utc.strftime("%Y:%d"), @existing_book.created_on.strftime("%Y:%d")
      end

      it "should set the updated_at column for new records" do
        assert_in_delta time.to_i, @new_book.updated_at.to_i, 1.second
      end

      it "should set the updated_on column for new records" do
        assert_in_delta time.to_i, @new_book.updated_on.to_i, 1.second
      end
    end

    context "when a custom time zone is set" do
      setup do
        Timecop.freeze(time) do
          assert_difference "Book.count", +1 do
            Book.import [:title, :author_name, :publisher], [["LDAP", "Big Bird", "Del Rey"]]
          end
        end
        @book = Book.last
      end

      it "should set the created_at and created_on timestamps for new records" do
        assert_in_delta time.to_i, @book.created_at.to_i, 1.second
        assert_in_delta time.to_i, @book.created_on.to_i, 1.second
      end

      it "should set the updated_at and updated_on timestamps for new records" do
        assert_in_delta time.to_i, @book.updated_at.to_i, 1.second
        assert_in_delta time.to_i, @book.updated_on.to_i, 1.second
      end
    end
  end

  context "importing with database reserved words" do
    let(:group) { Build(:group, order: "superx") }

    it "should import just fine" do
      assert_difference "Group.count", +1 do
        Group.import [group]
      end
      assert_equal "superx", Group.first.order
    end
  end

  context "importing a datetime field" do
    it "should import a date with YYYY/MM/DD format just fine" do
      Topic.import [:author_name, :title, :last_read], [["Bob Jones", "Topic 2", "2010/05/14"]]
      assert_equal "2010/05/14".to_date, Topic.last.last_read.to_date
    end
  end

  context "importing through an association scope" do
    { has_many: :chapters, polymorphic: :discounts }.each do |association_type, association|
      let(:book)   { FactoryGirl.create :book }
      let(:scope)  { book.public_send association }
      let(:klass)  { { chapters: Chapter, discounts: Discount }[association] }
      let(:column) { { chapters: :title,  discounts: :amount  }[association] }
      let(:val1)   { { chapters: 'A',     discounts: 5        }[association] }
      let(:val2)   { { chapters: 'B',     discounts: 6        }[association] }

      context "for #{association_type}" do
        it "works importing models" do
          scope.import [
            klass.new(column => val1),
            klass.new(column => val2)
          ]

          assert_equal [val1, val2], scope.map(&column).sort
        end

        it "works importing array of columns and values" do
          scope.import [column], [[val1], [val2]]

          assert_equal [val1, val2], scope.map(&column).sort
        end
      end
    end
  end

  context 'When importing models with Enum fields' do
    it 'should be able to import enum fields' do
      Book.delete_all if Book.count > 0
      books = [
        Book.new(author_name: "Foo", title: "Baz", status: 0),
        Book.new(author_name: "Foo2", title: "Baz2", status: 1),
      ]
      Book.import books
      assert_equal 2, Book.count

      if ENV['AR_VERSION'].to_i >= 5.0
        assert_equal 'draft', Book.first.read_attribute('status')
        assert_equal 'published', Book.last.read_attribute('status')
      else
        assert_equal 0, Book.first.read_attribute('status')
        assert_equal 1, Book.last.read_attribute('status')
      end
    end

    it 'should be able to import enum fields with default value' do
      Book.delete_all if Book.count > 0
      books = [
        Book.new(author_name: "Foo", title: "Baz")
      ]
      Book.import books
      assert_equal 1, Book.count

      if ENV['AR_VERSION'].to_i >= 5.0
        assert_equal 'draft', Book.first.read_attribute('status')
      else
        assert_equal 0, Book.first.read_attribute('status')
      end
    end

    if ENV['AR_VERSION'].to_f > 4.1
      it 'should be able to import enum fields by name' do
        Book.delete_all if Book.count > 0
        books = [
          Book.new(author_name: "Foo", title: "Baz", status: :draft),
          Book.new(author_name: "Foo2", title: "Baz2", status: :published),
        ]
        Book.import books
        assert_equal 2, Book.count

        if ENV['AR_VERSION'].to_i >= 5.0
          assert_equal 'draft', Book.first.read_attribute('status')
          assert_equal 'published', Book.last.read_attribute('status')
        else
          assert_equal 0, Book.first.read_attribute('status')
          assert_equal 1, Book.last.read_attribute('status')
        end
      end
    end
  end

  context 'When importing arrays of values with Enum fields' do
    let(:columns) { [:author_name, :title, :status] }
    let(:values) { [['Author #1', 'Book #1', 0], ['Author #2', 'Book #2', 1]] }

    it 'should be able to import enum fields' do
      Book.delete_all if Book.count > 0
      Book.import columns, values
      assert_equal 2, Book.count

      if ENV['AR_VERSION'].to_i >= 5.0
        assert_equal 'draft', Book.first.read_attribute('status')
        assert_equal 'published', Book.last.read_attribute('status')
      else
        assert_equal 0, Book.first.read_attribute('status')
        assert_equal 1, Book.last.read_attribute('status')
      end
    end
  end

  describe "importing when model has default_scope" do
    it "doesn't import the default scope values" do
      assert_difference "Widget.unscoped.count", +2 do
        Widget.import [:w_id], [[1], [2]]
      end
      default_scope_value = Widget.scope_attributes[:active]
      assert_not_equal default_scope_value, Widget.unscoped.find_by_w_id(1)
      assert_not_equal default_scope_value, Widget.unscoped.find_by_w_id(2)
    end

    it "imports columns that are a part of the default scope using the value specified" do
      assert_difference "Widget.unscoped.count", +2 do
        Widget.import [:w_id, :active], [[1, true], [2, false]]
      end
      assert_not_equal true, Widget.unscoped.find_by_w_id(1)
      assert_not_equal false, Widget.unscoped.find_by_w_id(2)
    end
  end

  describe "importing serialized fields" do
    it "imports values for serialized Hash fields" do
      assert_difference "Widget.unscoped.count", +1 do
        Widget.import [:w_id, :data], [[1, { a: :b }]]
      end
      assert_equal({ a: :b }, Widget.find_by_w_id(1).data)
    end

    it "imports values for serialized fields" do
      assert_difference "Widget.unscoped.count", +1 do
        Widget.import [:w_id, :unspecified_data], [[1, { a: :b }]]
      end
      assert_equal({ a: :b }, Widget.find_by_w_id(1).unspecified_data)
    end

    it "imports values for custom coder" do
      assert_difference "Widget.unscoped.count", +1 do
        Widget.import [:w_id, :custom_data], [[1, { a: :b }]]
      end
      assert_equal({ a: :b }, Widget.find_by_w_id(1).custom_data)
    end

    let(:data) { { a: :b } }
    it "imports values for serialized JSON fields" do
      assert_difference "Widget.unscoped.count", +1 do
        Widget.import [:w_id, :json_data], [[9, data]]
      end
      assert_equal(data.as_json, Widget.find_by_w_id(9).json_data)
    end

    context "with a store" do
      it "imports serialized attributes set using accessors" do
        vendors = [Vendor.new(name: 'Vendor 1', color: 'blue')]
        assert_difference "Vendor.count", +1 do
          Vendor.import vendors
        end
        assert_equal('blue', Vendor.first.color)
      end
    end
  end

  describe "#import!" do
    context "with an array of unsaved model instances" do
      let(:topics) { Build(2, :topics) }
      let(:invalid_topics) { Build(2, :invalid_topics) }

      context "with invalid data" do
        it "should raise ActiveRecord::RecordInvalid" do
          assert_no_difference "Topic.count" do
            assert_raise ActiveRecord::RecordInvalid do
              Topic.import! invalid_topics
            end
          end
        end
      end

      context "with valid data" do
        it "should import data" do
          assert_difference "Topic.count", +2 do
            Topic.import! topics
          end
        end
      end
    end

    context "with array of columns and array of values" do
      let(:columns) { %w(title author_name) }
      let(:valid_values) { [["LDAP", "Jerry Carter"], ["Rails Recipes", "Chad Fowler"]] }
      let(:invalid_values) { [["Rails Recipes", "Chad Fowler"], ["The RSpec Book", ""], ["Agile+UX", ""]] }

      context "with invalid data" do
        it "should raise ActiveRecord::RecordInvalid" do
          assert_no_difference "Topic.count" do
            assert_raise ActiveRecord::RecordInvalid do
              Topic.import! columns, invalid_values
            end
          end
        end
      end

      context "with valid data" do
        it "should import data" do
          assert_difference "Topic.count", +2 do
            Topic.import! columns, valid_values
          end
        end
      end
    end
  end
end
