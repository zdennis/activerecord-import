def should_support_basic_on_duplicate_key_update
  describe "#import" do
    extend ActiveSupport::TestCase::ImportAssertions

    macro(:perform_import) { raise "supply your own #perform_import in a context below" }
    macro(:updated_topic) { Topic.find(@topic.id) }

    context "with :on_duplicate_key_update and validation checks turned off" do
      asssertion_group(:should_support_on_duplicate_key_update) do
        should_not_update_fields_not_mentioned
        should_update_foreign_keys
        should_not_update_created_at_on_timestamp_columns
        should_update_updated_at_on_timestamp_columns
      end

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

      context "using an empty array" do
        let(:update_columns) { [] }
        should_not_update_fields_not_mentioned
        should_update_updated_at_on_timestamp_columns
      end

      context "using string column names" do
        let(:update_columns) { %w(title author_email_address parent_id) }
        should_support_on_duplicate_key_update
        should_update_fields_mentioned
      end

      context "using symbol column names" do
        let(:update_columns) { [:title, :author_email_address, :parent_id] }
        should_support_on_duplicate_key_update
        should_update_fields_mentioned
      end
    end

    context "with a table that has a non-standard primary key" do
      let(:columns) { [:promotion_id, :code] }
      let(:values) { [[1, 'DISCOUNT1']] }
      let(:updated_values) { [[1, 'DISCOUNT2']] }
      let(:update_columns) { [:code] }

      macro(:perform_import) do |*opts|
        Promotion.import columns, updated_values, opts.extract_options!.merge(on_duplicate_key_update: update_columns, validate: false)
      end
      macro(:updated_promotion) { Promotion.find(@promotion.promotion_id) }

      setup do
        Promotion.import columns, values, validate: false
        @promotion = Promotion.find 1
      end

      it "should update specified columns" do
        perform_import
        assert_equal 'DISCOUNT2', updated_promotion.code
      end
    end

    context "with :on_duplicate_key_update turned off" do
      let(:columns) { %w( id title author_name author_email_address parent_id ) }
      let(:values) { [[100, "Book", "John Doe", "john@doe.com", 17]] }
      let(:updated_values) { [[100, "Book - 2nd Edition", "This should raise an exception", "john@nogo.com", 57]] }

      macro(:perform_import) do |*opts|
        # `on_duplicate_key_update: false` is the tested feature
        Topic.import columns, updated_values, opts.extract_options!.merge(on_duplicate_key_update: false, validate: false)
      end

      setup do
        Topic.import columns, values, validate: false
        @topic = Topic.find 100
      end

      it "should raise ActiveRecord::RecordNotUnique" do
        assert_raise ActiveRecord::RecordNotUnique do
          perform_import
        end
      end
    end
  end
end
