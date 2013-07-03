require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

describe "#supports_imports?" do
  context "and SQLite is 3.7.11 or higher" do
    it "supports import" do
      version = ActiveRecord::ConnectionAdapters::SQLite3Adapter::Version.new("3.7.11")
      assert ActiveRecord::Base.supports_import?(version)

      version = ActiveRecord::ConnectionAdapters::SQLite3Adapter::Version.new("3.7.12")
      assert ActiveRecord::Base.supports_import?(version)
    end
  end

  context "and SQLite less than 3.7.11" do
    it "doesn't support import" do
      version = ActiveRecord::ConnectionAdapters::SQLite3Adapter::Version.new("3.7.10")
      assert !ActiveRecord::Base.supports_import?(version)
    end
  end
end

describe "#import" do
  it "import with a single insert on SQLite 3.7.11 or higher" do
    assert_difference "Topic.count", +10 do
      result = Topic.import Build(3, :topics)
      assert_equal 1, result.num_inserts, "Failed to issue a single INSERT statement. Make sure you have a supported version of SQLite3 (3.7.11 or higher) installed"

      result = Topic.import Build(7, :topics)
      assert_equal 1, result.num_inserts, "Failed to issue a single INSERT statement. Make sure you have a supported version of SQLite3 (3.7.11 or higher) installed"
    end
  end
end

