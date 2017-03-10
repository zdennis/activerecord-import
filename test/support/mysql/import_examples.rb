# encoding: UTF-8
def should_support_mysql_import_functionality
  # Forcefully disable strict mode for this session.
  ActiveRecord::Base.connection.execute "set sql_mode='STRICT_ALL_TABLES'"

  should_support_basic_on_duplicate_key_update
  should_support_on_duplicate_key_ignore

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
        topics << Topic.create!(title: "LDAP", author_name: "Big Bird")
        topics << Topic.create!(title: "Rails Recipes", author_name: "Elmo")
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

    describe "single_insert" do
      let(:values) do
        # generate "big" data to go above the default mysql max_allowed_packet limit
        max_allow_packet = Car.connection.execute("SHOW VARIABLES like 'max_allowed_packet';" ).to_a[0][1].to_i
        value = 'long_name_to_increase_size_of_the_packet_long_name_to_increase_size_of_the_packet_long_name_to_increase_size_of_the_packet_long_name_to_increase_size_of_the_packet_long_name_to_increase_size_of_the_packet_long_name_to_increase_size_of_the_packet'.freeze

        nb_values = (max_allow_packet / value.size) + 1
        Array.new(nb_values) do
          [value]
        end
      end

      context "with :single_insert option" do
        it "raise an error if max_allowed_packet is not big enought" do
          assert_raise ActiveRecord::StatementInvalid do
            begin
              Car.import ['Name'], values, validate: false, on_duplicate_key_ignore: true, single_insert: true
            ensure
              # as MySQL server has gone way we need to close and reopen the connection..
              Car.connection.close
              Car.first
            end
          end
        end
      end

      context "without :single_insert option" do
        it "succeed even if max_allowed_packet is not big enought" do
          assert_nothing_raised do
            Car.import ['Name'], values, validate: false, on_duplicate_key_ignore: true, single_insert: false
          end
        end
      end
    end
  end
end
