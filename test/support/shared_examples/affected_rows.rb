# frozen_string_literal: true

def should_support_affected_rows
  describe "#import" do
    extend ActiveSupport::TestCase::ImportAssertions

    context "with affected_rows tracking" do
      it "should return correct affected_rows count for basic import" do
        topics = Build(2, :topics)

        initial_count = Topic.count
        result = Topic.import topics, validate: false
        final_count = Topic.count
        actual_inserted = final_count - initial_count

        skip "affected_rows not supported on this adapter" if result.affected_rows.nil?

        assert_equal actual_inserted, result.affected_rows, "affected_rows should match actual database inserts"
      end

      it "should return correct affected_rows count with on_duplicate_key_ignore" do
        existing = Build(:topic)
        existing.save!

        topics = [
          Build(:topic, id: existing.id),  # This should be ignored
          Build(:topic)                    # This should be inserted
        ]

        initial_count = Topic.count
        result = Topic.import topics, on_duplicate_key_ignore: true, validate: false
        final_count = Topic.count
        actual_inserted = final_count - initial_count

        assert_equal 1, actual_inserted, "Database should show 1 new record (duplicate ignored)"

        skip "affected_rows not supported on this adapter" if result.affected_rows.nil?

        assert_equal actual_inserted, result.affected_rows, "affected_rows should match actual database inserts"
        assert_equal 1, result.num_inserts, "num_inserts should be 1 (single INSERT statement)"
      end
    end
  end
end
