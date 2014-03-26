require File.expand_path(File.dirname(__FILE__) + '/../test_helper')
require File.expand_path(File.dirname(__FILE__) + '/../support/postgresql/import_examples')

should_support_postgresql_import_functionality

describe '.import' do
  context 'with: hydrate_object_ids' do
    let(:options) { { :hydrate_object_ids => true } }
    let(:topics) { FactoryGirl.build_list(:topic_with_books, 3) }
    let(:books) { topics.collect(&:books).flatten.compact }

    setup do
      Topic.import topics, options
      Book.import books, options
    end

    it 'should set the primary key values into the model references' do
      assert topics.count > 0
      assert topics.all?(&:id)
    end

    it 'should set the foreign key values into the model references' do
      assert books.count > 0
      assert books.all?(&:topic_id)
    end
  end
end
