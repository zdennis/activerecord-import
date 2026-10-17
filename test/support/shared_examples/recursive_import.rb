# frozen_string_literal: true

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

    let(:new_question_with_rule) { FactoryBot.build :question, :with_rule }

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

    # Models are only valid if all associations are valid
    it "only imports models with valid associations" do
      assert_difference "Topic.count", 2 do
        assert_difference "Book.count", 4 do
          assert_difference "Chapter.count", 12 do
            assert_difference "EndNote.count", 16 do
              Topic.import new_topics_with_invalid_chapter, recursive: true
            end
          end
        end
      end
    end

    context "when associations have uniqueness validators" do
      let(:new_playlist) do
        Playlist.new(name: "Playlist").tap { |playlist| playlist.songs.build(title: "Song") }
      end

      setup do
        Playlist.import [Playlist.new(name: "Existing").tap { |playlist| playlist.songs.build(title: "Song") }], recursive: true
      end

      it "skips them by default" do
        assert_difference "Playlist.count", +1 do
          assert_difference "Song.count", +1 do
            Playlist.import [new_playlist], recursive: true
          end
        end
      end

      it "runs them if validate_uniqueness is true" do
        assert_no_difference "Playlist.count" do
          assert_no_difference "Song.count" do
            Playlist.import [new_playlist], recursive: true, validate_uniqueness: true
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

    it "sets foreign keys from the primary_key option of the association" do
      warehouse = Warehouse.new(identifier: 123_456_789)
      2.times { |i| warehouse.shipments.build(description: "Shipment ##{i}") }

      assert_difference "Shipment.count", +2 do
        Warehouse.import! [warehouse], recursive: true
      end

      assert_equal [123_456_789, 123_456_789], warehouse.shipments.map(&:warehouse_id)
      assert_equal 2, Warehouse.find(warehouse.id).shipments.count
    end

    it "imports an imported belongs_to association id" do
      first_new_topic = new_topics[0]
      second_new_topic = new_topics[1]

      books = first_new_topic.books.to_a
      Topic.import new_topics, validate: false

      assert_difference "Book.count", books.size do
        Book.import books, validate: false
      end

      books.each do |book|
        assert_equal book.topic_id, first_new_topic.id
      end

      books.each { |book| book.topic_id = second_new_topic.id }
      assert_no_difference "Book.count", books.size do
        Book.import books, validate: false, on_duplicate_key_update: [:topic_id]
      end

      books.each do |book|
        assert_equal book.topic_id, second_new_topic.id
      end

      books.each { |book| book.topic_id = nil }
      assert_no_difference "Book.count", books.size do
        Book.import books, validate: false, on_duplicate_key_update: [:topic_id]
      end

      books.each do |book|
        assert_nil book.topic_id, nil
      end
    end

    context "when a model is not valid" do
      # The issue [1] only occurs when the parent model has an ID set.
      # [1] https://github.com/zdennis/activerecord-import/issues/857
      let(:invalid_topics) { Build(1, :topic_with_book, author_name: nil, id: 1) }

      context "when validations are enabled" do
        it "does not import its associations" do
          assert_no_difference "Book.count" do
            Topic.import invalid_topics, validate: true, recursive: true
          end
        end
      end

      context "when validations are enabled and failures are tracked" do
        it "does not import its associations" do
          assert_no_difference "Book.count" do
            Topic.import invalid_topics, validate: true, recursive: true, track_validation_failures: true
          end
        end
      end

      context "when validations are not enabled" do
        it "import its associations anyway" do
          assert_difference "Book.count", invalid_topics.first.books.size do
            Topic.import invalid_topics, validate: false, recursive: true
          end
        end
      end
    end

    it "imports the associations of a model with errors left over from an earlier validation" do
      topic = Build(1, :topic_with_book).first
      topic.errors.add(:base, :invalid)

      assert_difference "Book.count", topic.books.size do
        Topic.import [topic], validate: false, recursive: true
      end
    end

    unless ENV["SKIP_COMPOSITE_PK"]
      describe "with composite primary keys" do
        it "should import models and set id" do
          tags = []
          tags << Tag.new(tag_id: 1, publisher_id: 1, tag: 'Mystery')
          tags << Tag.new(tag_id: 2, publisher_id: 1, tag: 'Science')

          assert_difference "Tag.count", +2 do
            Tag.import tags
          end

          assert_equal 1, tags[0].tag_id
          assert_equal 2, tags[1].tag_id
        end

        if ENV['AR_VERSION'].to_f >= 7.1
          it "should import models with auto-incrementing ID successfully with recursive set to true" do
            author = Author.create!(name: "Foo Barson")
            books = []
            2.times do |i|
              books << CompositeBook.new(author_id: author.id, title: "Book #{i}", composite_chapters: [
                                           CompositeChapter.new(title: "Book #{i} composite chapter 1"),
                                           CompositeChapter.new(title: "Book #{i} composite chapter 2"),
                                         ])
            end
            assert_difference "CompositeBook.count", +2 do
              assert_difference "CompositeChapter.count", +4 do
                CompositeBook.import books, recursive: true
              end
            end
          end

          it "sets foreign keys from the composite primary_key option of the association" do
            customer = Customer.new(account_id: 123_456_789, name: "Foo Barson")
            customer.orders.build(amount: 1)

            assert_difference "Order.count", +1 do
              Customer.import! [customer], recursive: true
            end

            order = Order.last
            assert_equal 123_456_789, order.account_id
            assert_equal customer.id, order.customer_id
          end
        end
      end
    end

    describe "all_or_none" do
      [Book, Chapter, Topic, EndNote].each do |type|
        it "creates #{type}" do
          assert_difference "#{type}.count", 0 do
            Topic.import new_topics_with_invalid_chapter, all_or_none: true, recursive: true
          end
        end
      end
    end

    # If adapter supports on_duplicate_key_update and specific columns are specified, it is only applied to top level models so that SQL with invalid
    # columns, keys, etc isn't generated for child associations when doing recursive import
    if ActiveRecord::Base.connection_pool.with_connection(&:supports_on_duplicate_key_update?)
      # MySQL's ON DUPLICATE KEY UPDATE takes just the columns to update, without a conflict target
      mysql_adapter = "ActiveRecord::Import::MysqlAdapter".safe_constantize
      mysql = mysql_adapter && ActiveRecord::Base.connection_pool.with_connection { |conn| conn.is_a?(mysql_adapter) }
      update_columns = ->(columns) { mysql ? columns : { conflict_target: [:id], columns: columns } }

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

        context "when :all fields are updated" do
          setup do
            Topic.import new_topics, recursive: true
          end

          it "updates associated objects" do
            new_author_name = 'Richard Bachman'
            topic = new_topics.first
            topic.books.each do |book|
              book.author_name = new_author_name
            end
            assert_nothing_raised do
              Topic.import new_topics, recursive: true, on_duplicate_key_update: :all
            end
            Topic.find(topic.id).books.each do |book|
              assert_equal new_author_name, book.author_name
            end
          end
        end
      end

      describe "recursive_on_duplicate_key_update" do
        let(:new_topics) { Build(1, :topic_with_book) }

        setup do
          Topic.import new_topics, recursive: true
        end

        it "updates associated objects" do
          new_author_name = 'Richard Bachman'
          topic = new_topics.first
          topic.books.each do |book|
            book.author_name = new_author_name
          end

          assert_nothing_raised do
            Topic.import new_topics,
              recursive: true,
              on_duplicate_key_update: [:id],
              recursive_on_duplicate_key_update: {
                books: update_columns.call([:author_name])
              }
          end
          Topic.find(topic.id).books.each do |book|
            assert_equal new_author_name, book.author_name
          end
        end

        it "updates nested associated objects" do
          new_chapter_title = 'The Final Chapter'
          book = new_topics.first.books.first
          book.author_name = 'Richard Bachman'

          example_chapter = book.chapters.first
          example_chapter.title = new_chapter_title

          assert_nothing_raised do
            Topic.import new_topics,
              recursive: true,
              on_duplicate_key_update: [:id],
              recursive_on_duplicate_key_update: {
                books: update_columns.call([:author_name]),
                chapters: update_columns.call([:title])
              }
          end
          assert_equal new_chapter_title, Chapter.find(example_chapter.id).title
        end

        it "resolves attribute aliases on the associated model" do
          playlist = Playlist.new(name: "Playlist")
          song = playlist.songs.build(title: "Song")
          Playlist.import [playlist], recursive: true
          song.title = "Renamed"

          Playlist.import [playlist],
            recursive: true,
            on_duplicate_key_update: [:name],
            recursive_on_duplicate_key_update: {
              songs: update_columns.call([:name])
            }
          assert_equal "Renamed", song.reload.title
        end

        context "when a non-standard association name is used" do
          let(:new_topics) do
            topic = Build(:topic)

            2.times do
              novel = topic.novels.build(title: FactoryBot.generate(:book_title), author_name: 'Stephen King')
              3.times do
                novel.chapters.build(title: FactoryBot.generate(:chapter_title))
              end

              4.times do
                novel.end_notes.build(note: FactoryBot.generate(:end_note))
              end
            end

            [topic]
          end

          it "updates nested associated objects" do
            new_chapter_title = 'The Final Chapter'
            novel = new_topics.first.novels.first
            novel.author_name = 'Richard Bachman'

            example_chapter = novel.chapters.first
            example_chapter.title = new_chapter_title

            assert_nothing_raised do
              Topic.import new_topics,
                recursive: true,
                on_duplicate_key_update: [:id],
                recursive_on_duplicate_key_update: {
                  novels: update_columns.call([:author_name]),
                  chapters: update_columns.call([:title])
                }
            end
            assert_equal new_chapter_title, Chapter.find(example_chapter.id).title
          end
        end
      end
    end

    describe "existing child records" do
      it "links an existing record assigned to a new parent" do
        book = Book.create!(title: "Existing", author_name: "Someone")
        topic = Build(:topic)
        topic.books = [book]

        Topic.import [topic], recursive: true, on_duplicate_key_update: :all

        assert_equal topic.id, book.reload.topic_id
      end

      it "doesn't import existing records already linked to the parent" do
        topic = Topic.create!(title: "Title", author_name: "Author")
        topic.books.create!(title: "Existing", author_name: "Someone")
        topic = Topic.includes(:books).find(topic.id)
        topic.title = "Changed"

        book_inserts = []
        subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
          book_inserts << payload[:sql] if payload[:sql] =~ /\AINSERT INTO "?books/i
        end
        begin
          Topic.import [topic], recursive: true, on_duplicate_key_update: [:title]
        ensure
          ActiveSupport::Notifications.unsubscribe(subscriber)
        end

        assert_equal [], book_inserts
      end

      it "leaves the records of a loaded has_many :through association alone" do
        topic = Topic.create!(title: "Title", author_name: "Author")
        book = topic.books.create!(title: "Existing", author_name: "Someone")
        chapter = book.chapters.create!(title: "Chapter")
        topic = Topic.includes(:books, :chapters).find(topic.id)
        topic.title = "Changed"

        Topic.import [topic], recursive: true, on_duplicate_key_update: [:title]

        assert_equal book.id, chapter.reload.book_id
      end
    end

    # If returning option is provided, it is only applied to top level models so that SQL with invalid
    # columns, keys, etc isn't generated for child associations when doing recursive import
    describe "returning" do
      let(:new_topics) { Build(1, :topic_with_book) }

      it "imports objects with associations" do
        assert_difference "Topic.count", +1 do
          Topic.import new_topics, recursive: true, returning: [:content], validate: false
          new_topics.each do |topic|
            assert_not_nil topic.id
          end
        end
      end
    end

    # If no returning option is provided, it is ignored
    describe "no returning" do
      let(:new_topics) { Build(1, :topic_with_book) }

      it "is ignored and imports objects with associations" do
        assert_difference "Topic.count", +1 do
          Topic.import new_topics, recursive: true, no_returning: true, validate: false
          new_topics.each do |topic|
            assert_not_nil topic.id
          end
        end
      end
    end
  end
end
