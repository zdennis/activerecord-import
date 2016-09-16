# encoding: UTF-8
def should_support_postgresql_import_functionality
  should_support_recursive_import

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

      setup do
        Topic.import columns, values, validate: false
      end

      it "should not update any records" do
        result = Topic.import columns, updated_values, on_duplicate_key_ignore: true, validate: false
        assert_equal [], result.ids
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
          Topic.import mixed_topics, recursive: true, on_duplicate_key_ignore: true
        end
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

        context 'with :index_predicate' do
          let(:columns) { %w( id device_id alarm_type status metadata ) }
          let(:values) { [[99, 17, 1, 1, 'foo']] }
          let(:updated_values) { [[99, 17, 1, 2, 'bar']] }

          macro(:perform_import) do |*opts|
            Alarm.import columns, updated_values, opts.extract_options!.merge(on_duplicate_key_update: { conflict_target: [:device_id, :alarm_type], index_predicate: 'status <> 0', columns: [:status] }, validate: false)
          end

          macro(:updated_alarm) { Alarm.find(@alarm.id) }

          setup do
            Alarm.import columns, values, validate: false
            @alarm = Alarm.find 99
          end

          assertion(:should_not_update_created_at_timestamp_columns) do
            Timecop.freeze Chronic.parse("5 minutes from now") do
              perform_import
              assert_in_delta @alarm.created_at.to_i, updated_alarm.created_at.to_i, 1
            end
          end

          assertion(:should_update_updated_at_timestamp_columns) do
            time = Chronic.parse("5 minutes from now")
            Timecop.freeze time do
              perform_import
              assert_in_delta time.to_i, updated_alarm.updated_at.to_i, 1
            end
          end

          assertion(:should_not_update_fields_not_mentioned) do
            assert_equal 'foo', updated_alarm.metadata
          end

          assertion(:should_update_fields_mentioned_with_hash_mappings) do
            perform_import
            assert_equal 2, updated_alarm.status
          end

          it 'supports on duplicate key update for partial indexes' do
            should_not_update_fields_not_mentioned
            should_not_update_created_at_on_timestamp_columns
            should_update_updated_at_on_timestamp_columns
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

        context "default to the primary key" do
          let(:columns) { %w( id title author_name author_email_address parent_id ) }
          let(:values) { [[100, "Book", "John Doe", "john@doe.com", 17]] }
          let(:updated_values) { [[100, "Book - 2nd Edition", "Author Should Not Change", "johndoe@example.com", 57]] }
          let(:update_columns) { [:title, :author_email_address, :parent_id] }

          setup do
            Topic.import columns, values, validate: false
            @topic = Topic.find 100
          end

          context "with no :conflict_target or :constraint_name" do
            macro(:perform_import) do |*opts|
              Topic.import columns, updated_values, opts.extract_options!.merge(on_duplicate_key_update: { columns: update_columns }, validate: false)
            end

            should_support_on_duplicate_key_update
            should_update_fields_mentioned
          end

          context "with empty value for :conflict_target" do
            macro(:perform_import) do |*opts|
              Topic.import columns, updated_values, opts.extract_options!.merge(on_duplicate_key_update: { conflict_target: [], columns: update_columns }, validate: false)
            end

            should_support_on_duplicate_key_update
            should_update_fields_mentioned
          end

          context "with empty value for :constraint_name" do
            macro(:perform_import) do |*opts|
              Topic.import columns, updated_values, opts.extract_options!.merge(on_duplicate_key_update: { constraint_name: '', columns: update_columns }, validate: false)
            end

            should_support_on_duplicate_key_update
            should_update_fields_mentioned
          end
        end

        context "with no :conflict_target or :constraint_name" do
          context "with no primary key" do
            it "raises ArgumentError" do
              error = assert_raises ArgumentError do
                Widget.import Build(1, :widgets), on_duplicate_key_update: [:data], validate: false
              end
              assert_match(/Expected :conflict_target or :constraint_name to be specified/, error.message)
            end
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
    end
  end
end
