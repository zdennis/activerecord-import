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
  end
end
