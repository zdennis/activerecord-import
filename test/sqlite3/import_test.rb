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
  it "imports with a single insert on SQLite 3.7.11 or higher" do
    assert_difference "Topic.count", +507 do
      result = Topic.import Build(7, :topics)
      assert_equal 1, result.num_inserts, "Failed to issue a single INSERT statement. Make sure you have a supported version of SQLite3 (3.7.11 or higher) installed"
      assert_equal 7, Topic.count, "Failed to insert all records. Make sure you have a supported version of SQLite3 (3.7.11 or higher) installed"

      result = Topic.import Build(500, :topics)
      assert_equal 1, result.num_inserts, "Failed to issue a single INSERT statement. Make sure you have a supported version of SQLite3 (3.7.11 or higher) installed"
      assert_equal 507, Topic.count, "Failed to insert all records. Make sure you have a supported version of SQLite3 (3.7.11 or higher) installed"
    end
  end

  it "imports with a two inserts on SQLite 3.7.11 or higher" do
    assert_difference "Topic.count", +501 do
      result = Topic.import Build(501, :topics)
      assert_equal 2, result.num_inserts, "Failed to issue a two INSERT statements. Make sure you have a supported version of SQLite3 (3.7.11 or higher) installed"
      assert_equal 501, Topic.count, "Failed to insert all records. Make sure you have a supported version of SQLite3 (3.7.11 or higher) installed"
    end
  end

  it "imports with a five inserts on SQLite 3.7.11 or higher" do
    assert_difference "Topic.count", +2500 do
      result = Topic.import Build(2500, :topics)
      assert_equal 5, result.num_inserts, "Failed to issue a two INSERT statements. Make sure you have a supported version of SQLite3 (3.7.11 or higher) installed"
      assert_equal 2500, Topic.count, "Failed to insert all records. Make sure you have a supported version of SQLite3 (3.7.11 or higher) installed"
    end
  end

end

