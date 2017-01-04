def should_support_replace
  describe '#supports_replace?' do
    it "returns true" do
      assert ActiveRecord::Base.supports_replace?
    end
  end

  describe '#import' do
    let(:columns) { %w( id shopping_cart_id book_id ) }
    let(:values) { [[1, 1, 2], [2, 1, 3]] }
    let(:new_values) { [[3, 1, 2], [4, 1, 4]] }

    macro(:perform_import) do |*opts|
      CartItem.import columns, new_values, opts.extract_options!.merge(replace: true)
    end

    setup do
      CartItem.import columns, values
    end

    it "should replace conflicting rows" do
      perform_import
      refute CartItem.find_by(id: 1).present?, "deletes conflicting rows"
      assert CartItem.find_by(id: 3).present?, "inserts new rows"
    end

    it "should insert new rows" do
      perform_import
      assert CartItem.find_by(id: 4).present?, "inserts new rows"
    end
  end
end

def should_not_support_replace
  describe '#supports_replace?' do
    it "returns false" do
      refute ActiveRecord::Base.supports_replace?
    end
  end
end
