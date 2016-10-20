def should_support_on_duplicate_key_ignore
  describe "#import" do
    extend ActiveSupport::TestCase::ImportAssertions
    let(:topic) { Topic.create!(title: "Book", author_name: "John Doe") }
    let(:topics) { [topic] }

    context "with :on_duplicate_key_ignore" do
      it "should skip duplicates and continue import" do
        topics << Topic.new(title: "Book 2", author_name: "Jane Doe")
        assert_difference "Topic.count", +1 do
          Topic.import topics, on_duplicate_key_ignore: true, validate: false
        end
      end
    end

    context "with :ignore" do
      it "should skip duplicates and continue import" do
        topics << Topic.new(title: "Book 2", author_name: "Jane Doe")
        assert_difference "Topic.count", +1 do
          Topic.import topics, ignore: true, validate: false
        end
      end
    end
  end
end
