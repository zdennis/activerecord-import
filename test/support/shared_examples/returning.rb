# frozen_string_literal: true

# For adapters that use INSERT ... RETURNING to set the primary key of imported objects
def should_support_returning
  describe "#import" do
    context "setting attributes and marking clean" do
      let(:topic) { Build(:topics) }

      setup { Topic.import([topic]) }

      it "assigns ids" do
        assert topic.id.present?
      end

      it "marks models as clean" do
        assert !topic.changed?
      end

      it "moves the dirty changes to previous_changes" do
        assert topic.previous_changes.present?
      end

      it "marks models as persisted" do
        assert !topic.new_record?
        assert topic.persisted?
      end

      it "assigns timestamps" do
        assert topic.created_at.present?
        assert topic.updated_at.present?
      end
    end

    describe "with query cache enabled" do
      setup do
        unless ActiveRecord::Base.connection_pool.with_connection(&:query_cache_enabled)
          ActiveRecord::Base.connection_pool.with_connection(&:enable_query_cache!)
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
          ActiveRecord::Base.connection_pool.with_connection(&:disable_query_cache!)
        end
      end
    end

    describe "no_returning" do
      let(:books) { [Book.new(author_name: "foo", title: "bar")] }

      it "creates records" do
        assert_difference "Book.count", +1 do
          Book.import books, no_returning: true
        end
      end

      it "returns no ids" do
        assert_equal [], Book.import(books, no_returning: true).ids
      end

      macro :capture_insert_queries do |&block|
        queries = []
        subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
          queries << payload if payload[:sql].start_with?("INSERT")
        end
        begin
          block.call
        ensure
          ActiveSupport::Notifications.unsubscribe(subscriber)
        end
        queries
      end

      it "does not add a RETURNING clause when importing models" do
        queries = capture_insert_queries { Book.import books, no_returning: true }

        assert_equal 1, queries.size
        assert_equal "Book Create Many", queries.first[:name]
        refute_match(/RETURNING/i, queries.first[:sql])
      end

      it "does not add a RETURNING clause when importing hashes" do
        queries = capture_insert_queries do
          Book.import [{ author_name: "foo", title: "bar" }], no_returning: true
        end

        assert_equal 1, queries.size
        assert_equal "Book Create Many", queries.first[:name]
        refute_match(/RETURNING/i, queries.first[:sql])
      end

      it "clears the query cache" do
        Book.cache do
          before_import = Book.count
          Book.import books, no_returning: true
          assert_equal before_import + 1, Book.count
        end
      end
    end

    describe "returning" do
      let(:books) { [Book.new(author_name: "King", title: "It")] }
      let(:result) { Book.import(books, returning: %w(author_name title)) }
      let(:book_id) { books.first.id }

      it "creates records" do
        assert_difference("Book.count", +1) { result }
      end

      it "returns ids" do
        result
        assert_equal [book_id], result.ids
      end

      it "returns specified columns" do
        assert_equal [%w(King It)], result.results
      end

      context "when given an empty array" do
        let(:result) { Book.import([], returning: %w(title)) }

        setup { result }

        it "returns empty arrays for ids and results" do
          assert_equal [], result.ids
          assert_equal [], result.results
        end
      end

      context "when primary key and returning overlap" do
        let(:result) { Book.import(books, returning: %w(id title)) }

        setup { result }

        it "returns ids" do
          assert_equal [book_id], result.ids
        end

        it "returns specified columns" do
          assert_equal [[book_id, 'It']], result.results
        end
      end
    end

    context "with :on_duplicate_key_ignore and :recursive enabled" do
      let(:new_topic) { Build(1, :topic_with_book) }
      let(:mixed_topics) { Build(1, :topic_with_book) + new_topic + Build(1, :topic_with_book) }

      setup do
        Topic.import new_topic, recursive: true
      end

      # Recursive import depends on the primary keys of the parent model being returned
      # on insert. With on_duplicate_key_ignore enabled, not all ids will be returned
      # and it is possible that a model will be assigned the wrong id and then its children
      # would be associated with the wrong parent.
      it ":on_duplicate_key_ignore is ignored" do
        assert_raise ActiveRecord::RecordNotUnique do
          Topic.import mixed_topics, recursive: true, on_duplicate_key_ignore: true, validate: false
        end
      end
    end
  end
end
