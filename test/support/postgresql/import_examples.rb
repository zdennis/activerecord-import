# frozen_string_literal: true

def should_support_postgresql_import_functionality
  should_support_recursive_import
  should_support_returning

  if ActiveRecord::Base.connection_pool.with_connection(&:supports_on_duplicate_key_update?)
    should_support_postgresql_upsert_functionality
  end

  describe "#supports_imports?" do
    it "should support import" do
      assert ActiveRecord::Base.supports_import?
    end
  end

  describe "#returning_selections" do
    it "should quote known columns" do
      selections = Topic.connection_pool.with_connection do |conn|
        conn.send(:returning_selections, model: Topic, primary_key: "id", returning: ["title", "now()"])
      end
      assert_equal ['"id"', '"title"', "now()"], selections
    end

    it "should return the selections unchanged without a model" do
      selections = Topic.connection_pool.with_connection do |conn|
        conn.send(:returning_selections, primary_key: "id", returning: ["title"])
      end
      assert_equal %w(id title), selections
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

    describe "with a column the database populates" do
      let(:key) { "0e4c1c5e-6a3e-4b8a-9f1e-3c2d7b6a5f40" }

      it "leaves the column out when no model assigns it" do
        License.import [License.new(name: "First"), License.new(name: "Second")]
        assert License.pluck(:key).all?(&:present?)
      end

      it "inserts assigned values" do
        License.import [License.new(name: "First", key: key)]
        assert_equal key, License.last.key
      end

      it "inserts the column when any model assigns it" do
        License.import [License.new(name: "First", key: key), License.new(name: "Second")]
        assert_equal key, License.order(:id).first.key
      end

      it "lets the database populate the column for models that don't assign it" do
        License.import [License.new(name: "First", key: key), License.new(name: "Second")]
        assert License.find_by(name: "Second").key.present?
      end

      it "inserts the column when it is listed explicitly" do
        License.import [:name, :key], [License.new(name: "First")]
        assert_nil License.last.key
      end

      it "inserts the column for persisted models" do
        license = License.create!(name: "First")
        license.name = "Renamed"
        License.import [license], on_duplicate_key_update: [:name]
        assert_equal "Renamed", license.reload.name
        assert license.key.present?
      end
    end

    describe "returning" do
      let(:books) { [Book.new(author_name: "King", title: "It")] }
      let(:result) { Book.import(books, returning: %w(author_name title)) }
      let(:book_id) { books.first.id }
      let(:true_returning_value) { true }
      let(:false_returning_value) { false }

      context "when a returning column is a serialized attribute" do
        let(:vendor) { Vendor.new(hours: { monday: '8-5' }) }
        let(:result) { Vendor.import([vendor], returning: %w(hours)) }

        it "creates records" do
          assert_difference("Vendor.count", +1) { result }
        end
      end

      context "when returning is raw sql" do
        let(:result) { Book.import(books, returning: "title, (xmax = '0') AS inserted") }

        setup { result }

        it "returns ids" do
          assert_equal [book_id], result.ids
        end

        it "returns specified columns" do
          assert_equal [['It', true_returning_value]], result.results
        end
      end

      context "when returning contains raw sql" do
        let(:result) { Book.import(books, returning: [:title, "id, (xmax = '0') AS inserted"]) }

        setup { result }

        it "returns ids" do
          assert_equal [book_id], result.ids
        end

        it "returns specified columns" do
          assert_equal [['It', book_id, true_returning_value]], result.results
        end
      end

      context "setting model attributes" do
        let(:code) { 'abc' }
        let(:discount) { 0.10 }
        let(:original_promotion) do
          Promotion.new(code: code, discount: discount)
        end
        let(:updated_promotion) do
          Promotion.new(code: code, description: 'ABC discount')
        end
        let(:returning_columns) { %w(discount) }

        setup do
          Promotion.import([original_promotion])
          Promotion.import([updated_promotion],
            on_duplicate_key_update: { conflict_target: %i(code), columns: %i(description) },
            returning: returning_columns)
        end

        it "sets model attributes" do
          assert_equal updated_promotion.discount, discount
        end

        context "returning multiple columns" do
          let(:returning_columns) { %w(discount description) }

          it "sets model attributes" do
            assert_equal updated_promotion.discount, discount
          end
        end

        context 'returning raw sql' do
          let(:returning_columns) { [:discount, "(xmax = '0') AS inserted"] }

          it "sets custom model attributes" do
            assert_equal updated_promotion.inserted, false_returning_value
          end
        end
      end
    end
  end

  describe "with a uuid primary key" do
    let(:vendor) { Vendor.new(name: "foo") }
    let(:vendors) { [vendor] }

    it "creates records" do
      assert_difference "Vendor.count", +1 do
        Vendor.import vendors
      end
    end

    it "assigns an id to the model objects" do
      Vendor.import vendors
      assert_not_nil vendor.id
    end

    describe "with an assigned uuid primary key" do
      let(:id) { SecureRandom.uuid }
      let(:vendor) { Vendor.new(id: id, name: "foo") }
      let(:vendors) { [vendor] }

      it "creates records with correct id" do
        assert_difference "Vendor.count", +1 do
          Vendor.import vendors
        end
        assert_equal id, vendor.id
      end
    end

    describe "with a uuid primary key assigned to only some models" do
      let(:id) { SecureRandom.uuid }

      it "keeps the assigned ids when the first model doesn't have one" do
        assert_difference "Vendor.count", +2 do
          Vendor.import [Vendor.new(name: "new"), Vendor.new(id: id, name: "assigned")]
        end
        assert_equal "assigned", Vendor.find(id).name
      end

      it "lets the database populate the ids of the other models" do
        vendors = [Vendor.new(id: id, name: "assigned"), Vendor.new(name: "new")]
        assert_difference "Vendor.count", +2 do
          Vendor.import vendors
        end
        assert_equal id, vendors.first.id
        assert vendors.last.id.present?
      end

      it "updates existing records and creates new ones on duplicate key update" do
        vendor = Vendor.create!(name: "old")
        vendor.name = "updated"
        assert_difference "Vendor.count", +1 do
          Vendor.import [Vendor.new(name: "new"), vendor], on_duplicate_key_update: [:name]
        end
        assert_equal "updated", vendor.reload.name
      end

      it "lets the database populate the ids missing from hashes" do
        assert_difference "Vendor.count", +2 do
          Vendor.import [{ id: id, name: "assigned" }, { id: nil, name: "new" }]
        end
        assert_equal "assigned", Vendor.find(id).name
      end

      it "lets the database populate the ids missing from arrays" do
        assert_difference "Vendor.count", +2 do
          Vendor.import [:id, :name], [[id, "assigned"], [nil, "new"]]
        end
        assert_equal "assigned", Vendor.find(id).name
      end
    end
  end

  describe "with a primary key the database populates with a function" do
    it "lets the database populate the ids when no model has one" do
      coupons = [Coupon.new(name: "First"), Coupon.new(name: "Second")]
      assert_difference "Coupon.count", +2 do
        Coupon.import coupons
      end
      assert(coupons.all? { |coupon| coupon.id.present? })
    end

    it "keeps the assigned ids and lets the database populate the others" do
      assert_difference "Coupon.count", +2 do
        Coupon.import [Coupon.new(name: "First"), Coupon.new(id: "SPRING", name: "Second")]
      end
      assert_equal "Second", Coupon.find("SPRING").name
    end
  end

  describe "with store accessor fields" do
    it "imports values for json fields" do
      vendors = [Vendor.new(name: 'Vendor 1', size: 100)]
      assert_difference "Vendor.count", +1 do
        Vendor.import vendors
      end
      assert_equal(100, Vendor.first.size)
    end

    it "imports values for hstore fields" do
      vendors = [Vendor.new(name: 'Vendor 1', contact: 'John Smith')]
      assert_difference "Vendor.count", +1 do
        Vendor.import vendors
      end
      assert_equal('John Smith', Vendor.first.contact)
    end

    it "imports values for jsonb fields" do
      vendors = [Vendor.new(name: 'Vendor 1', charge_code: '12345')]
      assert_difference "Vendor.count", +1 do
        Vendor.import vendors
      end
      assert_equal('12345', Vendor.first.charge_code)
    end
  end

  describe "with serializable fields" do
    it "imports default values as correct data type" do
      vendors = [Vendor.new(name: 'Vendor 1')]
      assert_difference "Vendor.count", +1 do
        Vendor.import vendors
      end
      assert_equal({}, Vendor.first.json_data)
    end

    %w(json jsonb).each do |json_type|
      describe "with pure #{json_type} fields" do
        let(:data) { { a: :b } }
        let(:json_field_name) { "pure_#{json_type}_data" }
        it "imports the values from saved records" do
          vendor = Vendor.create!(name: 'Vendor 1', json_field_name => data)

          Vendor.import [vendor], on_duplicate_key_update: [json_field_name]
          assert_equal(data.as_json, vendor.reload[json_field_name])
        end
      end
    end
  end

  describe "with enum field" do
    let(:vendor_type) { "retailer" }
    it "imports the correct values for enum fields" do
      vendor = Vendor.new(name: 'Vendor 1', vendor_type: vendor_type)
      assert_difference "Vendor.count", +1 do
        Vendor.import [vendor]
      end
      assert_equal(vendor_type, Vendor.first.vendor_type)
    end
  end

  describe "with binary field" do
    let(:binary_value) { "\xE0'c\xB2\xB0\xB3Bh\\\xC2M\xB1m\\I\xC4r".dup.force_encoding('ASCII-8BIT') }
    it "imports the correct values for binary fields" do
      alarms = [Alarm.new(device_id: 1, alarm_type: 1, status: 1, secret_key: binary_value)]
      assert_difference "Alarm.count", +1 do
        Alarm.import alarms
      end
      assert_equal(binary_value, Alarm.first.secret_key)
    end
  end

  unless ENV["SKIP_COMPOSITE_PK"]
    describe "with composite foreign keys" do
      let(:account_id) { 555 }
      let(:customer) { Customer.new(account_id: account_id, name: "foo") }
      let(:order) { Order.new(account_id: account_id, amount: 100, customer: customer) }

      it "imports and correctly maps foreign keys" do
        assert_difference "Customer.count", +1 do
          Customer.import [customer]
        end

        assert_difference "Order.count", +1 do
          Order.import [order]
        end

        db_customer = Customer.last
        db_order = Order.last

        assert_equal db_customer.orders.last, db_order
        assert_not_equal db_order.customer_id, nil
      end

      it "maps foreign keys from a parent imported after the child was built" do
        order # built while the customer has no id, so its customer_id is blank

        Customer.import [customer]
        Order.import [order]

        db_order = Order.last
        assert_equal customer.id, db_order.customer_id
        assert_equal account_id, db_order.account_id
      end

      it "should import models with auto-incrementing ID successfully" do
        author = Author.create!(name: "Foo Barson")

        books = []
        2.times do |i|
          books << CompositeBook.new(author_id: author.id, title: "book #{i}")
        end
        assert_difference "CompositeBook.count", +2 do
          CompositeBook.import books
        end
      end

      if ENV['AR_VERSION'].to_f >= 7.1
        describe "returning the id column" do
          let(:author) { Author.create!(name: "Foo Barson") }

          it "sets the id column on models" do
            books = [CompositeBook.new(author_id: author.id, title: "Book 1"),
                     CompositeBook.new(author_id: author.id, title: "Book 2")]
            result = CompositeBook.import books, returning: %i[id title]

            ids = CompositeBook.order(:id).pluck(:id)
            assert_equal ids.map { |id| [id, author.id] }, books.map(&:id)
            assert_equal ids, books.map(&:id_value)
            assert_equal ids.zip(["Book 1", "Book 2"]), result.results
            assert books.none?(&:changed?)
          end

          it "imports hashes that include the id column with validations" do
            next_id = CompositeBook.maximum(:id).to_i + 100
            books = [{ id: next_id, author_id: author.id, title: "Book 1" }]

            assert_difference "CompositeBook.count", +1 do
              result = CompositeBook.import! books, returning: %i[id title]
              assert_equal [[next_id, "Book 1"]], result.results
            end
            assert CompositeBook.exists?(id: next_id, author_id: author.id)
          end
        end
      end
    end
  end
end

def should_support_postgresql_upsert_functionality
  should_support_basic_on_duplicate_key_update
  should_support_on_duplicate_key_ignore

  describe "#import" do
    extend ActiveSupport::TestCase::ImportAssertions

    macro(:perform_import) { raise "supply your own #perform_import in a context below" }
    macro(:updated_topic) { Topic.find(@topic.id) }

    context "with :on_duplicate_key_ignore and validation checks turned off" do
      let(:columns) { %w( id title author_name author_email_address parent_id ) }
      let(:values) { [[99, "Book", "John Doe", "john@doe.com", 17]] }
      let(:updated_values) { [[99, "Book - 2nd Edition", "Author Should Not Change", "johndoe@example.com", 57]] }

      setup do
        Topic.import columns, values, validate: false
      end

      it "should not update any records" do
        result = Topic.import columns, updated_values, on_duplicate_key_ignore: true, validate: false
        assert_equal [], result.ids
      end
    end

    context "with :on_duplicate_key_update and validation checks turned off" do
      asssertion_group(:should_support_on_duplicate_key_update) do
        should_not_update_fields_not_mentioned
        should_update_foreign_keys
        should_not_update_created_at_on_timestamp_columns
        should_update_updated_at_on_timestamp_columns
      end

      context "using a hash" do
        context "with :columns :all" do
          let(:columns) { %w( id title author_name author_email_address parent_id ) }
          let(:updated_values) { [[99, "Book - 2nd Edition", "Jane Doe", "janedoe@example.com", 57]] }

          macro(:perform_import) do |*opts|
            Topic.import columns, updated_values, opts.extract_options!.merge(on_duplicate_key_update: { conflict_target: :id, columns: :all }, validate: false)
          end

          setup do
            values = [[99, "Book", "John Doe", "john@doe.com", 17, 3]]
            Topic.import columns + ['replies_count'], values, validate: false
          end

          it "should update all specified columns" do
            perform_import
            updated_topic = Topic.find(99)
            assert_equal 'Book - 2nd Edition', updated_topic.title
            assert_equal 'Jane Doe', updated_topic.author_name
            assert_equal 'janedoe@example.com', updated_topic.author_email_address
            assert_equal 57, updated_topic.parent_id
            assert_equal 3, updated_topic.replies_count
          end

          it "should not overwrite created timestamps when importing models" do
            created_at = Topic.find(99).created_at

            Timecop.freeze(Chronic.parse("5 minutes from now")) do
              Topic.import [Topic.new(id: 99, title: "Book - 2nd Edition", author_name: "Jane Doe")],
                on_duplicate_key_update: { conflict_target: :id, columns: :all }, validate: false
            end

            assert_in_delta created_at.to_i, Topic.find(99).created_at.to_i, 1.second
          end
        end

        context "with :columns a hash" do
          let(:columns) { %w( id title author_name author_email_address parent_id ) }
          let(:values) { [[99, "Book", "John Doe", "john@doe.com", 17]] }
          let(:updated_values) { [[99, "Book - 2nd Edition", "Author Should Not Change", "johndoe@example.com", 57]] }

          macro(:perform_import) do |*opts|
            Topic.import columns, updated_values, opts.extract_options!.merge(on_duplicate_key_update: { conflict_target: :id, columns: update_columns }, validate: false)
          end

          setup do
            Topic.import columns, values, validate: false
            @topic = Topic.find 99
          end

          it "should not modify the passed in :on_duplicate_key_update columns array" do
            assert_nothing_raised do
              columns = %w(title author_name).freeze
              Topic.import columns, [%w(foo, bar)], { on_duplicate_key_update: { columns: columns }.freeze }.freeze
            end
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

        context 'with :index_predicate' do
          let(:columns) { %w( id device_id alarm_type status metadata ) }
          let(:values) { [[99, 17, 1, 1, 'foo']] }
          let(:updated_values) { [[99, 17, 1, 2, 'bar']] }

          macro(:perform_import) do |*opts|
            Alarm.import columns, updated_values, opts.extract_options!.merge(on_duplicate_key_update: { conflict_target: [:device_id, :alarm_type], index_predicate: 'status <> 0', columns: [:status] }, validate: false)
          end

          macro(:updated_alarm) { Alarm.find(@alarm.id) }

          setup do
            Alarm.import columns, values, validate: false
            @alarm = Alarm.find 99
          end

          context 'supports on duplicate key update for partial indexes' do
            it 'should not update created_at timestamp columns' do
              Timecop.freeze Chronic.parse("5 minutes from now") do
                perform_import
                assert_in_delta @alarm.created_at.to_i, updated_alarm.created_at.to_i, 1
              end
            end

            it 'should update updated_at timestamp columns' do
              time = Chronic.parse("5 minutes from now")
              Timecop.freeze time do
                perform_import
                assert_in_delta time.to_i, updated_alarm.updated_at.to_i, 1
              end
            end

            it 'should not update fields not mentioned' do
              perform_import
              assert_equal 'foo', updated_alarm.metadata
            end

            it 'should update fields mentioned with hash mappings' do
              perform_import
              assert_equal 2, updated_alarm.status
            end
          end
        end

        context 'with :condition' do
          let(:columns) { %w( id device_id alarm_type status metadata) }
          let(:values) { [[99, 17, 1, 1, 'foo']] }
          let(:updated_values) { [[99, 17, 1, 1, 'bar']] }

          macro(:perform_import) do |*opts|
            Alarm.import(
              columns,
              updated_values,
              opts.extract_options!.merge(
                on_duplicate_key_update: {
                  conflict_target: [:id],
                  condition: "alarms.metadata NOT LIKE '%foo%'",
                  columns: [:metadata]
                },
                validate: false
              )
            )
          end

          macro(:updated_alarm) { Alarm.find(@alarm.id) }

          setup do
            Alarm.import columns, values, validate: false
            @alarm = Alarm.find 99
          end

          it 'should not update fields not matched' do
            perform_import
            assert_equal 'foo', updated_alarm.metadata
          end
        end

        context "with :constraint_name" do
          let(:columns) { %w( id title author_name author_email_address parent_id ) }
          let(:values) { [[100, "Book", "John Doe", "john@doe.com", 17]] }
          let(:updated_values) { [[100, "Book - 2nd Edition", "Author Should Not Change", "johndoe@example.com", 57]] }

          macro(:perform_import) do |*opts|
            Topic.import columns, updated_values, opts.extract_options!.merge(on_duplicate_key_update: { constraint_name: :topics_pkey, columns: update_columns }, validate: false)
          end

          setup do
            Topic.import columns, values, validate: false
            @topic = Topic.find 100
          end

          let(:update_columns) { [:title, :author_email_address, :parent_id] }
          should_support_on_duplicate_key_update
          should_update_fields_mentioned
        end

        context "default to the primary key" do
          let(:columns) { %w( id title author_name author_email_address parent_id ) }
          let(:values) { [[100, "Book", "John Doe", "john@doe.com", 17]] }
          let(:updated_values) { [[100, "Book - 2nd Edition", "Author Should Not Change", "johndoe@example.com", 57]] }
          let(:update_columns) { [:title, :author_email_address, :parent_id] }

          setup do
            Topic.import columns, values, validate: false
            @topic = Topic.find 100
          end

          context "with no :conflict_target or :constraint_name" do
            macro(:perform_import) do |*opts|
              Topic.import columns, updated_values, opts.extract_options!.merge(on_duplicate_key_update: { columns: update_columns }, validate: false)
            end

            should_support_on_duplicate_key_update
            should_update_fields_mentioned
          end

          context "with empty value for :conflict_target" do
            macro(:perform_import) do |*opts|
              Topic.import columns, updated_values, opts.extract_options!.merge(on_duplicate_key_update: { conflict_target: [], columns: update_columns }, validate: false)
            end

            should_support_on_duplicate_key_update
            should_update_fields_mentioned
          end

          context "with empty value for :constraint_name" do
            macro(:perform_import) do |*opts|
              Topic.import columns, updated_values, opts.extract_options!.merge(on_duplicate_key_update: { constraint_name: '', columns: update_columns }, validate: false)
            end

            should_support_on_duplicate_key_update
            should_update_fields_mentioned
          end
        end

        context "with no :conflict_target or :constraint_name" do
          context "with a primary key named after a reserved word" do
            it "uses the quoted primary key as the conflict target" do
              Section.import %w(order name), [[1, "Intro"]], validate: false
              Section.import %w(order name), [[1, "Introduction"]], on_duplicate_key_update: [:name], validate: false

              assert_equal 1, Section.count
              assert_equal "Introduction", Section.find(1).name
            end
          end

          context "with no primary key" do
            it "raises ArgumentError" do
              error = assert_raises ArgumentError do
                Rule.import Build(3, :rules), on_duplicate_key_update: [:condition_text], validate: false
              end
              assert_match(/Expected :conflict_target or :constraint_name to be specified/, error.message)
            end
          end
        end

        context "with no :columns" do
          let(:columns) { %w( id title author_name author_email_address ) }
          let(:values) { [[100, "Book", "John Doe", "john@doe.com"]] }
          let(:updated_values) { [[100, "Title Should Not Change", "Author Should Not Change", "john@nogo.com"]] }

          macro(:perform_import) do |*opts|
            Topic.import columns, updated_values, opts.extract_options!.merge(on_duplicate_key_update: { conflict_target: :id }, validate: false)
          end

          setup do
            Topic.import columns, values, validate: false
            @topic = Topic.find 100
          end

          should_update_updated_at_on_timestamp_columns
        end
      end
    end
  end
end
