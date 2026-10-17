# frozen_string_literal: true

def should_support_mysql_import_functionality
  # Forcefully disable strict mode for this session.
  ActiveRecord::Base.connection_pool.with_connection { |conn| conn.execute "set sql_mode='STRICT_ALL_TABLES'" }

  should_support_basic_on_duplicate_key_update
  should_support_on_duplicate_key_ignore
  should_support_affected_rows

  describe "#import" do
    context "with :on_duplicate_key_update and validation checks turned off" do
      extend ActiveSupport::TestCase::ImportAssertions

      asssertion_group(:should_support_on_duplicate_key_update) do
        should_not_update_fields_not_mentioned
        should_update_foreign_keys
        should_not_update_created_at_on_timestamp_columns
        should_update_updated_at_on_timestamp_columns
      end

      macro(:perform_import) { raise "supply your own #perform_import in a context below" }
      macro(:updated_topic) { Topic.find(@topic.id) }

      let(:columns) { %w( id title author_name author_email_address parent_id ) }
      let(:values) { [[99, "Book", "John Doe", "john@doe.com", 17]] }
      let(:updated_values) { [[99, "Book - 2nd Edition", "Author Should Not Change", "johndoe@example.com", 57]] }

      macro(:perform_import) do |*opts|
        Topic.import columns, updated_values, opts.extract_options!.merge(on_duplicate_key_update: update_columns, validate: false)
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

    context "with :synchronization option" do
      let(:topics) { [] }
      let(:values) { [[topics.first.id, "Jerry Carter", "title1"], [topics.last.id, "Chad Fowler", "title2"]] }
      let(:columns) { %w(id author_name title) }

      setup do
        topics << Topic.create!(title: "LDAP", author_name: "Big Bird", content: "Putting Directories to Work.")
        topics << Topic.create!(title: "Rails Recipes", author_name: "Elmo", content: "A trusted collection of solutions.")
      end

      it "synchronizes passed in ActiveRecord model instances with the data just imported" do
        columns2update = ['author_name']

        expected_count = Topic.count
        Topic.import( columns, values,
          validate: false,
          on_duplicate_key_update: columns2update,
          synchronize: topics )

        assert_equal expected_count, Topic.count, "no new records should have been created!"
        assert_equal "Jerry Carter", topics.first.author_name, "wrong author!"
        assert_equal "Chad Fowler", topics.last.author_name, "wrong author!"
      end
    end

    context "affected_rows" do
      it "is reported for an import" do
        result = Topic.import %w(title author_name), [%w(Book1 Author1), %w(Book2 Author2)], validate: false, no_returning: true
        assert_equal 2, result.affected_rows
      end

      it "counts a row updated by on_duplicate_key_update twice" do
        Topic.import %w(id title author_name), [[99, "Book", "Author"]], validate: false
        result = Topic.import %w(id title author_name), [[99, "Book - 2nd Edition", "Author"]],
          validate: false, no_returning: true, on_duplicate_key_update: [:title]
        assert_equal 2, result.affected_rows
      end
    end

    context "with the query cache enabled" do
      it "clears the query cache" do
        Topic.cache do
          before_import = Topic.count
          Topic.import Build(2, :topics), validate: false
          assert_equal before_import + 2, Topic.count
        end
      end
    end

    context "with virtual columns" do
      let(:books) { [Book.new(author_name: "foo", title: "bar")] }

      it "ignores virtual columns and creates record" do
        assert_difference "Book.count", +1 do
          Book.import books
        end
      end
    end

    context "with annotations on the current scope" do
      let(:columns) { %w(title author_name) }
      let(:values) { [%w(Book1 Author1), %w(Book2 Author2), %w(Book3 Author3)] }

      it "adds them to each insert it splits the import into" do
        single_insert = capture_insert_sql do
          Topic.annotate("NOTE_ME").import columns, values.take(1), validate: false, timestamps: false
        end.first

        # Allow only one record per insert
        Topic.connection_pool.with_connection do |conn|
          conn.stubs(:max_allowed_packet).returns(single_insert.bytesize + ActiveRecord::Import::MysqlAdapter::QUERY_OVERHEAD)
        end

        sql = capture_insert_sql do
          assert_difference "Topic.count", +3 do
            result = Topic.annotate("NOTE_ME").import columns, values, validate: false, timestamps: false
            assert_equal 3, result.num_inserts
          end
        end

        assert_equal 3, sql.size
        sql.each { |statement| assert_includes statement, " /* NOTE_ME */" }
      end
    end
  end

  describe "#supports_setting_primary_key_of_imported_objects?" do
    supports_setting_primary_key = lambda do |mariadb:, version:|
      ActiveRecord::Base.connection_pool.with_connection do |conn|
        conn.stubs(:mariadb?).returns(mariadb)
        conn.stubs(:database_version).returns(ActiveRecord::ConnectionAdapters::AbstractAdapter::Version.new(version))
        conn.supports_setting_primary_key_of_imported_objects?
      end
    end

    it "is true for MariaDB 10.5 and later" do
      assert supports_setting_primary_key.call(mariadb: true, version: "10.5.0")
      assert supports_setting_primary_key.call(mariadb: true, version: "11.8.2")
    end

    it "is false for MariaDB before 10.5" do
      assert !supports_setting_primary_key.call(mariadb: true, version: "10.4.34")
    end

    it "is false for MySQL" do
      assert !supports_setting_primary_key.call(mariadb: false, version: "11.0.0")
    end
  end

  if ActiveRecord::Base.connection_pool.with_connection(&:supports_setting_primary_key_of_imported_objects?)
    should_support_mariadb_returning_functionality
  end
end

# MariaDB 10.5+ supports INSERT ... RETURNING, which sets the primary key of imported objects
def should_support_mariadb_returning_functionality
  should_support_recursive_import
  should_support_returning

  describe "#import" do
    context "with :on_duplicate_key_update" do
      let(:original_promotion) { Promotion.new(code: "abc", discount: 10) }
      let(:updated_promotion) { Promotion.new(code: "abc", description: "ABC discount") }
      let(:new_promotion) { Promotion.new(code: "xyz", description: "XYZ discount") }

      setup do
        Promotion.import([original_promotion])
        Promotion.import([updated_promotion, new_promotion], on_duplicate_key_update: [:description], returning: %w(discount))
      end

      it "assigns the ids of updated and inserted records" do
        assert_equal original_promotion.promotion_id, updated_promotion.promotion_id
        assert_equal Promotion.find_by(code: "xyz").promotion_id, new_promotion.promotion_id
      end

      it "sets returned attributes" do
        assert_equal 10, updated_promotion.discount
      end
    end

    context "when the insert is split to fit max_allowed_packet" do
      let(:topics) { Build(10, :topics) }

      setup do
        ActiveRecord::Base.connection_pool.with_connection { |conn| conn.stubs(:max_allowed_packet).returns(1200) }
      end

      it "assigns ids from every insert" do
        result = Topic.import topics
        assert_operator result.num_inserts, :>, 1
        assert_equal Topic.order(:id).last(10).map(&:id), topics.map(&:id)
      end
    end
  end
end
