# encoding: UTF-8
def should_support_postgresql_import_functionality
  describe "#supports_imports?" do
    it "should support import" do
      assert ActiveRecord::Base.supports_import?
    end
  end

  describe "#import" do
    it "should import with a single insert" do
      # see ActiveRecord::ConnectionAdapters::AbstractAdapter test for more specifics
      assert_difference "Topic.count", +10 do
        result = Topic.import Build(3, :topics)
        assert_equal 1, result.num_inserts

        result = Topic.import Build(7, :topics)
        assert_equal 1, result.num_inserts
      end
    end

    describe "importing objects with associations" do
      let(:new_topics) { Build(num_topics, :topic_with_book) }
      let(:new_topics_with_invalid_chapter) do
        chapter = new_topics.first.books.first.chapters.first
        chapter.title = nil
        new_topics
      end
      let(:num_topics) { 3 }
      let(:num_books) { 6 }
      let(:num_chapters) { 18 }
      let(:num_endnotes) { 24 }

      let(:new_question_with_rule) { FactoryGirl.build :question, :with_rule }

      it 'imports top level' do
        assert_difference "Topic.count", +num_topics do
          Topic.import new_topics, recursive: true
          new_topics.each do |topic|
            assert_not_nil topic.id
          end
        end
      end

      it 'imports first level associations' do
        assert_difference "Book.count", +num_books do
          Topic.import new_topics, recursive: true
          new_topics.each do |topic|
            topic.books.each do |book|
              assert_equal topic.id, book.topic_id
            end
          end
        end
      end

      it 'imports polymorphic associations' do
        discounts = Array.new(1) { |i| Discount.new(amount: i) }
        books = Array.new(1) { |i| Book.new(author_name: "Author ##{i}", title: "Book ##{i}") }
        books.each do |book|
          book.discounts << discounts
        end
        Book.import books, recursive: true
        books.each do |book|
          book.discounts.each do |discount|
            assert_not_nil discount.discountable_id
            assert_equal 'Book', discount.discountable_type
          end
        end
      end

      [{ recursive: false }, {}].each do |import_options|
        it "skips recursion for #{import_options}" do
          assert_difference "Book.count", 0 do
            Topic.import new_topics, import_options
          end
        end
      end

      it 'imports deeper nested associations' do
        assert_difference "Chapter.count", +num_chapters do
          assert_difference "EndNote.count", +num_endnotes do
            Topic.import new_topics, recursive: true
            new_topics.each do |topic|
              topic.books.each do |book|
                book.chapters.each do |chapter|
                  assert_equal book.id, chapter.book_id
                end
                book.end_notes.each do |endnote|
                  assert_equal book.id, endnote.book_id
                end
              end
            end
          end
        end
      end

      it "skips validation of the associations if requested" do
        assert_difference "Chapter.count", +num_chapters do
          Topic.import new_topics_with_invalid_chapter, validate: false, recursive: true
        end
      end

      it 'imports has_one associations' do
        assert_difference 'Rule.count' do
          Question.import [new_question_with_rule], recursive: true
        end
      end

      # These models dont validate associated.  So we expect that books and topics get inserted, but not chapters
      # Putting a transaction around everything wouldn't work, so if you want your chapters to prevent topics from
      # being created, you would need to have validates_associated in your models and insert with validation
      describe "all_or_none" do
        [Book, Topic, EndNote].each do |type|
          it "creates #{type}" do
            assert_difference "#{type}.count", send("num_#{type.to_s.downcase}s") do
              Topic.import new_topics_with_invalid_chapter, all_or_none: true, recursive: true
            end
          end
        end
        it "doesn't create chapters" do
          assert_difference "Chapter.count", 0 do
            Topic.import new_topics_with_invalid_chapter, all_or_none: true, recursive: true
          end
        end
      end
    end

    describe "with query cache enabled" do
      setup do
        unless ActiveRecord::Base.connection.query_cache_enabled
          ActiveRecord::Base.connection.enable_query_cache!
          @disable_cache_on_teardown = true
        end
      end

      it "clears cache on insert" do
        before_import = Topic.all.to_a

        Topic.import(Build(2, :topics), validate: false)

        after_import = Topic.all.to_a
        assert_equal 2, after_import.size - before_import.size
      end

      teardown do
        if @disable_cache_on_teardown
          ActiveRecord::Base.connection.disable_query_cache!
        end
      end
    end
  end
end

def should_support_postgresql_upsert_functionality
  should_support_basic_on_duplicate_key_update

  describe "#import" do
    extend ActiveSupport::TestCase::ImportAssertions

    macro(:perform_import) { raise "supply your own #perform_import in a context below" }
    macro(:updated_topic) { Topic.find(@topic.id) }

    context "with :on_duplicate_key_ignore and validation checks turned off" do
      let(:columns) { %w( id title author_name author_email_address parent_id ) }
      let(:values) { [[99, "Book", "John Doe", "john@doe.com", 17]] }
      let(:updated_values) { [[99, "Book - 2nd Edition", "Author Should Not Change", "johndoe@example.com", 57]] }

      macro(:perform_import) do |*opts|
        Topic.import columns, updated_values, opts.extract_options!.merge(on_duplicate_key_ignore: value, validate: false)
      end

      setup do
        Topic.import columns, values, validate: false
        @topic = Topic.find 99
      end

      context "using true" do
        let(:value) { true }
        should_not_update_updated_at_on_timestamp_columns
      end

      context "using hash with :conflict_target" do
        let(:value) { { conflict_target: :id } }
        should_not_update_updated_at_on_timestamp_columns
      end

      context "using hash with :constraint_target" do
        let(:value) { { constraint_name: :topics_pkey } }
        should_not_update_updated_at_on_timestamp_columns
      end
    end

    context "with :on_duplicate_key_update and validation checks turned off" do
      asssertion_group(:should_support_on_duplicate_key_update) do
        should_not_update_fields_not_mentioned
        should_update_foreign_keys
        should_not_update_created_at_on_timestamp_columns
        should_update_updated_at_on_timestamp_columns
      end

      context "using a hash" do
        context "with :columns a hash" do
          let(:columns) { %w( id title author_name author_email_address parent_id ) }
          let(:values) { [[99, "Book", "John Doe", "john@doe.com", 17]] }
          let(:updated_values) { [[99, "Book - 2nd Edition", "Author Should Not Change", "johndoe@example.com", 57]] }

          macro(:perform_import) do |*opts|
            Topic.import columns, updated_values, opts.extract_options!.merge(on_duplicate_key_update: { conflict_target: :id, columns: update_columns }, validate: false)
          end

          setup do
            Topic.import columns, values, validate: false
            @topic = Topic.find 99
          end

          context "using string hash map" do
            let(:update_columns) { { "title" => "title", "author_email_address" => "author_email_address", "parent_id" => "parent_id" } }
            should_support_on_duplicate_key_update
            should_update_fields_mentioned
          end

          context "using string hash map, but specifying column mismatches" do
            let(:update_columns) { { "title" => "author_email_address", "author_email_address" => "title", "parent_id" => "parent_id" } }
            should_support_on_duplicate_key_update
            should_update_fields_mentioned_with_hash_mappings
          end

          context "using symbol hash map" do
            let(:update_columns) { { title: :title, author_email_address: :author_email_address, parent_id: :parent_id } }
            should_support_on_duplicate_key_update
            should_update_fields_mentioned
          end

          context "using symbol hash map, but specifying column mismatches" do
            let(:update_columns) { { title: :author_email_address, author_email_address: :title, parent_id: :parent_id } }
            should_support_on_duplicate_key_update
            should_update_fields_mentioned_with_hash_mappings
          end
        end

        context "with :constraint_name" do
          let(:columns) { %w( id title author_name author_email_address parent_id ) }
          let(:values) { [[100, "Book", "John Doe", "john@doe.com", 17]] }
          let(:updated_values) { [[100, "Book - 2nd Edition", "Author Should Not Change", "johndoe@example.com", 57]] }

          macro(:perform_import) do |*opts|
            Topic.import columns, updated_values, opts.extract_options!.merge(on_duplicate_key_update: { constraint_name: :topics_pkey, columns: update_columns }, validate: false)
          end

          setup do
            Topic.import columns, values, validate: false
            @topic = Topic.find 100
          end

          let(:update_columns) { [:title, :author_email_address, :parent_id] }
          should_support_on_duplicate_key_update
          should_update_fields_mentioned
        end

        context "with no :conflict_target or :constraint_name" do
          let(:columns) { %w( id title author_name author_email_address parent_id ) }
          let(:values) { [[100, "Book", "John Doe", "john@doe.com", 17]] }
          let(:updated_values) { [[100, "Book - 2nd Edition", "Author Should Not Change", "johndoe@example.com", 57]] }

          macro(:perform_import) do |*opts|
            Topic.import columns, updated_values, opts.extract_options!.merge(on_duplicate_key_update: { columns: update_columns }, validate: false)
          end

          setup do
            Topic.import columns, values, validate: false
            @topic = Topic.find 100
          end

          context "default to the primary key" do
            let(:update_columns) { [:title, :author_email_address, :parent_id] }
            should_support_on_duplicate_key_update
            should_update_fields_mentioned
          end
        end

        context "with no :columns" do
          let(:columns) { %w( id title author_name author_email_address ) }
          let(:values) { [[100, "Book", "John Doe", "john@doe.com"]] }
          let(:updated_values) { [[100, "Title Should Not Change", "Author Should Not Change", "john@nogo.com"]] }

          macro(:perform_import) do |*opts|
            Topic.import columns, updated_values, opts.extract_options!.merge(on_duplicate_key_update: { conflict_target: :id }, validate: false)
          end

          setup do
            Topic.import columns, values, validate: false
            @topic = Topic.find 100
          end

          should_update_updated_at_on_timestamp_columns
        end
      end

      context "with recursive: true" do
        let(:new_topics) { Build(1, :topic_with_book) }

        it "imports objects with associations" do
          assert_difference "Topic.count", +1 do
            Topic.import new_topics, recursive: true, on_duplicate_key_update: [:updated_at], validate: false
            new_topics.each do |topic|
              assert_not_nil topic.id
            end
          end
        end
      end
    end
  end
end
