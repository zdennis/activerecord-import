def should_support_import_unique_records
  describe '#import' do
    extend ActiveSupport::TestCase::ImportAssertions

    context 'with :unique_records_by' do
      context 'when comparing with :all columns' do
        let(:topics) do
          Array.new(5) do
            Topic.new(author_name: 'John Doe', title: 'Sir John', content: 'Content Doe')
          end
        end

        it 'skips duplicated instances passed for import when comparing by all columns' do
          assert_difference 'Topic.count', +1 do
            Topic.import topics, unique_records_by: :all
          end
        end

        it 'imports all different instances that do not have the same value in all columns' do
          topics.last.title = 'Sir John last'

          assert_difference 'Topic.count', +2 do
            Topic.import topics, unique_records_by: :all
          end
        end
      end

      context 'when comparing with specific columns' do
        let(:topics) do
          Array.new(5) do |n|
            Topic.new(author_name: 'John Doe', title: "Sir John #{n}", content: 'Content Doe')
          end
        end

        it 'skips instances that share the same value in the specified columns' do
          5.times do |n|
            topics << Topic.new(author_name: 'John Doe', title: "Sir John #{n}")
          end

          assert_difference 'Topic.count', +5 do
            Topic.import topics, unique_records_by: %i(title)
          end
        end
      end

      it 'skips duplicated hashes passed for import' do
        topic_hashes = Array.new(5) do
          { author_name: 'John Doe', title: 'Sir John', content: 'Content Doe' }
        end

        assert_difference 'Topic.count', +1 do
          Topic.import topic_hashes, unique_records_by: :all
        end
      end
    end
  end
end
