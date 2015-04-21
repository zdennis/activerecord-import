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

    describe "importing objects with associations" do

      let(:new_topics) { Build(num_topics, :topic_with_book) }
      let(:new_topics_with_invalid_chapter) {
         chapter = new_topics.first.books.first.chapters.first
         chapter.title = nil
         new_topics
      }
      let(:num_topics) {3}
      let(:num_books) {6}
      let(:num_chapters) {18}
      let(:num_endnotes) {24}

      it 'imports top level' do
        assert_difference "Topic.count", +num_topics do
          Topic.import new_topics, :recursive => true
          new_topics.each do |topic|
            assert_not_nil topic.id
          end
        end
      end

      it 'imports first level associations' do
        assert_difference "Book.count", +num_books do
          Topic.import new_topics, :recursive => true
          new_topics.each do |topic|
            topic.books.each do |book|
              assert_equal topic.id, book.topic_id
            end
          end
        end
      end

      [{:recursive => false}, {}].each do |import_options|
        it "skips recursion for #{import_options.to_s}" do
          assert_difference "Book.count", 0 do
            Topic.import new_topics, import_options
          end
        end
      end

      it 'imports deeper nested associations' do
        assert_difference "Chapter.count", +num_chapters do
          assert_difference "EndNote.count", +num_endnotes do
            Topic.import new_topics, :recursive => true
            new_topics.each do |topic|
              topic.books.each do |book|
                book.chapters.each do |chapter|
                  assert_equal book.id, chapter.book_id
                end
                book.end_notes.each do |endnote|
                  assert_equal book.id, endnote.book_id
                end
              end
            end
          end
        end
      end

      it "skips validation of the associations if requested" do
        assert_difference "Chapter.count", +num_chapters do
          Topic.import new_topics_with_invalid_chapter, :validate => false, :recursive => true
        end
      end

      # These models dont validate associated.  So we expect that books and topics get inserted, but not chapters
      # Putting a transaction around everything wouldn't work, so if you want your chapters to prevent topics from
      # being created, you would need to have validates_associated in your models and insert with validation
      describe "all_or_none" do
        [Book, Topic, EndNote].each do |type|
          it "creates #{type.to_s}" do
            assert_difference "#{type.to_s}.count", send("num_#{type.to_s.downcase}s") do
              Topic.import new_topics_with_invalid_chapter, :all_or_none => true, :recursive => true
            end
          end
        end
        it "doesn't create chapters" do
          assert_difference "Chapter.count", 0 do
            Topic.import new_topics_with_invalid_chapter, :all_or_none => true, :recursive => true
          end
        end
      end
    end
  end
end
