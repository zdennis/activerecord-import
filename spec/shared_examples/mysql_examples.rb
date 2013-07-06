# encoding: UTF-8
shared_examples 'mysql import functionality' do
  before do
    # Forcefully disable strict mode for this session because Rails 4
    # sets the mode to strict by default.
    ActiveRecord::Base.connection.execute "set sql_mode=''"
  end

  describe '.get_insert_value_sets' do
    let(:adapter){ ActiveRecord::Base.connection.class }

    context 'given a collection of SQL value sets' do
      # each value set makes up 13 bytes
      let(:value1){ "('1','2','3')" }
      let(:value2){ "('4','5','6')" }
      let(:value3){ "('7','8','9')" }

      let(:values){ [value1, value2, value3] }

      it 'returns a collection of SQL value sets combining as many as possible based on the given base_sql_bytes and max_bytes' do
        value_sets = adapter.get_insert_value_sets values, base_sql_bytes=15, max_bytes=30
        value_sets.should eql([[value1], [value2], [value3]])
      end

      context 'and the base_sql_bytes is small enough to combine two of three given value sets' do
        it 'returns a collection with a single value set array' do
          value_sets = adapter.get_insert_value_sets values, base_sql_bytes=2, max_bytes=30
          value_sets.should eql([[value1, value2], [value3]])
        end
      end

      context 'and the max_bytes is large enough to combine all the given value sets' do
        it 'returns a collection with a single value set array' do
          value_sets = adapter.get_insert_value_sets values, base_sql_bytes=15, max_bytes=56
          value_sets.should eql([[value1, value2, value3]])
        end
      end

      context 'and the max_bytes is large enough to combine only two of the three given value sets' do
        it 'returns a collection with two value set arrays' do
          value_sets = adapter.get_insert_value_sets values, base_sql_bytes=15, max_bytes=43
          value_sets.should eql([[value1, value2], [value3]])
        end
      end

      context 'and the given value sets contain multi-byte characters' do
        # each value set is 6 bytes because each accented character is 2 bytes
        let(:value1){ "('é')" }
        let(:value2){ "('é')" }
        let(:values){ [value1, value2] }

        it 'combines the returned value sets based on the proper byte count' do
          value_sets = adapter.get_insert_value_sets values, base_sql_bytes=15, max_bytes=27
          value_sets.should eql([[value1], [value2]])

          value_sets = adapter.get_insert_value_sets values, base_sql_bytes=15, max_bytes=28
          value_sets.should eql([[value1, value2]])
        end
      end
    end
  end

  describe '#import with :on_duplicate_key_update option (mysql specific functionality)' do
    context 'with validation checks turned off' do
      context 'importing from an array of raw values' do
        include_examples 'mysql :on_duplicate_key_update examples for option types with validation off'
      end

      context 'importing from an array of model instances' do
        let(:perform_import) do
          topic.title = 'Book - 2nd Edition'
          topic.author_name = 'Author Should Not Change'
          topic.author_email_address = 'johndoe@example.com'
          topic.parent_id = 57
          Topic.import [topic], :on_duplicate_key_update => update_columns, :validate => false
        end

        include_examples 'mysql :on_duplicate_key_update examples for option types with validation off'
      end
    end
  end

  describe '#import with :synchronization option' do
    let(:topics){ Array.new }
    let(:values){ [ [topics.first.id, 'Jerry Carter'], [topics.last.id, 'Chad Fowler'] ]}
    let(:columns){ %W(id author_name) }

    before do
      topics << Topic.create!(:title=>'LDAP', :author_name=>'Big Bird')
      topics << Topic.create!(:title=>'Rails Recipes', :author_name=>'Elmo')
    end

    it 'synchronizes the given ActiveRecord model instances with the data just imported' do
      Topic.import columns, values, \
        :validate                => false,
        :on_duplicate_key_update => [:author_name],
        :synchronize             => topics

      expect(topics[0].author_name).to eql('Jerry Carter')
      expect(topics[1].author_name).to eql('Chad Fowler')
    end
  end
end

shared_examples 'mysql :on_duplicate_key_update with validation off' do |options|
  let(:columns_to_update){ options[:columns_to_update] }
  let(:columns){  %w( id title author_name author_email_address parent_id ) }
  let(:values){ [ [ 99, 'Book', 'John Doe', 'john@doe.com', 17 ] ] }
  let(:updated_values){ [ [ 99, 'Book - 2nd Edition', 'Author Should Not Change', 'johndoe@example.com', 57 ] ] }

  let(:topic){ Topic.find(99) }

  let(:perform_import) do
    Topic.import columns, updated_values, :on_duplicate_key_update => columns_to_update, :validate => false
  end

  before do
    # first, seed an existing set of values
    Topic.import columns, values, :validate => false
  end

  it 'updates fields mentioned' do
    expect {
      perform_import
      topic.reload
    }.to change(topic, :title)
  end

  it 'does not update fields not mentioned' do
    expect {
      perform_import
      topic.reload
    }.to_not change(topic, :author_name)
  end

  it 'updates foreign key columns mentioned' do
    expect {
      perform_import
      topic.reload
    }.to change(topic, :parent_id).from(17).to(57)
  end

  it 'does not update created_at' do
    Delorean.time_travel_to('5 minutes from now') do
      expect {
        perform_import
        topic.reload
      }.to_not change(topic, :created_at)
    end
  end

  it 'does not update created_on' do
    Delorean.time_travel_to('5 minutes from now') do
      expect {
        perform_import
        topic.reload
      }.to_not change(topic, :created_on)
    end
  end
end

shared_examples 'mysql :on_duplicate_key_update examples for option types with validation off' do
  context 'and using string column names' do
    include_examples 'mysql :on_duplicate_key_update with validation off',
      :columns_to_update => ['title', 'author_email_address', 'parent_id']
  end

  context 'and using symbol column names' do
    include_examples 'mysql :on_duplicate_key_update with validation off',
      :columns_to_update => [:title, :author_email_address, :parent_id]
  end

  context 'and using string hash map' do
    include_examples 'mysql :on_duplicate_key_update with validation off',
      :columns_to_update => {'title' => 'title', 'author_email_address' => 'author_email_address', 'parent_id' => 'parent_id'}
  end

  context 'and using string hash map with column mis-matches' do
    include_examples 'mysql :on_duplicate_key_update with validation off',
      :columns_to_update => {'title' => 'author_email_address', 'author_email_address' => 'title', 'parent_id' => 'parent_id'}

    it 'updates the mis-matched fields properly' do
      perform_import
      expect(topic.title).to eql('johndoe@example.com')
      expect(topic.author_email_address).to eql('Book - 2nd Edition')
    end
  end

  context 'and using symbol hash map' do
    include_examples 'mysql :on_duplicate_key_update with validation off',
      :columns_to_update => {:title => :title, :author_email_address => :author_email_address, :parent_id => :parent_id}
  end

  context 'and using symbol hash map with column mis-matches' do
    include_examples 'mysql :on_duplicate_key_update with validation off',
      :columns_to_update => {:title => :author_email_address, :author_email_address => :title, :parent_id => :parent_id}

    it 'updates the mis-matched fields properly' do
      perform_import
      expect(topic.title).to eql('johndoe@example.com')
      expect(topic.author_email_address).to eql('Book - 2nd Edition')
    end
  end
end

