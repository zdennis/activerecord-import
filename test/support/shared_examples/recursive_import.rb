def should_support_recursive_import
  describe "importing objects with associations" do
    let(:new_topics) { Build(num_topics, :topic_with_book) }
    let(:new_topics_with_invalid_chapter) do
      chapter = new_topics.first.books.first.chapters.first
      chapter.title = nil
      new_topics
    end
    let(:num_topics) { 3 }
    let(:num_books) { 6 }
    let(:num_chapters) { 18 }
    let(:num_endnotes) { 24 }

    let(:new_question_with_rule) { FactoryGirl.build :question, :with_rule }

    it 'imports top level' do
      assert_difference "Topic.count", +num_topics do
        Topic.import new_topics, recursive: true
        new_topics.each do |topic|
          assert_not_nil topic.id
        end
      end
    end

    it 'imports first level associations' do
      assert_difference "Book.count", +num_books do
        Topic.import new_topics, recursive: true
        new_topics.each do |topic|
          topic.books.each do |book|
            assert_equal topic.id, book.topic_id
          end
        end
      end
    end

    it 'imports polymorphic associations' do
      discounts = Array.new(1) { |i| Discount.new(amount: i) }
      books = Array.new(1) { |i| Book.new(author_name: "Author ##{i}", title: "Book ##{i}") }
      books.each do |book|
        book.discounts << discounts
      end
      Book.import books, recursive: true
      books.each do |book|
        book.discounts.each do |discount|
          assert_not_nil discount.discountable_id
          assert_equal 'Book', discount.discountable_type
        end
      end
    end

    it 'imports polymorphic associations from subclass' do
      discounts = Array.new(1) { |i| Discount.new(amount: i) }
      dictionaries = Array.new(1) { |i| Dictionary.new(author_name: "Author ##{i}", title: "Book ##{i}") }
      dictionaries.each do |dictionary|
        dictionary.discounts << discounts
      end
      Dictionary.import dictionaries, recursive: true
      assert_equal 1, Dictionary.last.discounts.count
      dictionaries.each do |dictionary|
        dictionary.discounts.each do |discount|
          assert_not_nil discount.discountable_id
          assert_equal 'Book', discount.discountable_type
        end
      end
    end

    [{ recursive: false }, {}].each do |import_options|
      it "skips recursion for #{import_options}" do
        assert_difference "Book.count", 0 do
          Topic.import new_topics, import_options
        end
      end
    end

    it 'imports deeper nested associations' do
      assert_difference "Chapter.count", +num_chapters do
        assert_difference "EndNote.count", +num_endnotes do
          Topic.import new_topics, recursive: true
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
        Topic.import new_topics_with_invalid_chapter, validate: false, recursive: true
      end
    end

    it 'imports has_one associations' do
      assert_difference 'Rule.count' do
        Question.import [new_question_with_rule], recursive: true
      end
    end

    # These models dont validate associated.  So we expect that books and topics get inserted, but not chapters
    # Putting a transaction around everything wouldn't work, so if you want your chapters to prevent topics from
    # being created, you would need to have validates_associated in your models and insert with validation
    describe "all_or_none" do
      [Book, Topic, EndNote].each do |type|
        it "creates #{type}" do
          assert_difference "#{type}.count", send("num_#{type.to_s.downcase}s") do
            Topic.import new_topics_with_invalid_chapter, all_or_none: true, recursive: true
          end
        end
      end
      it "doesn't create chapters" do
        assert_difference "Chapter.count", 0 do
          Topic.import new_topics_with_invalid_chapter, all_or_none: true, recursive: true
        end
      end
    end

    # If adapter supports on_duplicate_key_update, it is only applied to top level models so that SQL with invalid
    # columns, keys, etc isn't generated for child associations when doing recursive import
    if ActiveRecord::Base.connection.supports_on_duplicate_key_update?
      describe "on_duplicate_key_update" do
        let(:new_topics) { Build(1, :topic_with_book) }

        it "imports objects with associations" do
          assert_difference "Topic.count", +1 do
            Topic.import new_topics, recursive: true, on_duplicate_key_update: [:updated_at], validate: false
            new_topics.each do |topic|
              assert_not_nil topic.id
            end
          end
        end
      end
    end
  end
end
