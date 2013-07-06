require 'spec_helper'

require 'activerecord-import/active_record/adapters/abstract_adapter'

describe ActiveRecord::ConnectionAdapters::AbstractAdapter do
  context "#get_insert_value_sets - computing insert value sets" do
    let(:adapter){ ActiveRecord::ConnectionAdapters::AbstractAdapter }
    let(:base_sql){ "INSERT INTO atable (a,b,c)" }
    let(:values){ [ "(1,2,3)", "(2,3,4)", "(3,4,5)" ] }

    context "when the max allowed bytes is 33 and the base SQL is 26 bytes" do
      it "should return 3 value sets when given 3 value sets of 7 bytes a piece" do
        value_sets = adapter.get_insert_value_sets values, base_sql.size, max_allowed_bytes = 33
        expect(value_sets.size).to eq(3)
      end
    end

    context "when the max allowed bytes is 40 and the base SQL is 26 bytes" do
      it "should return 3 value sets when given 3 value sets of 7 bytes a piece" do
        value_sets = adapter.get_insert_value_sets values, base_sql.size, max_allowed_bytes = 40
        expect(value_sets.size).to eq(3)
      end
    end

    context "when the max allowed bytes is 41 and the base SQL is 26 bytes" do
      it "should return 2 value sets when given 2 value sets of 7 bytes a piece" do
        value_sets = adapter.get_insert_value_sets values, base_sql.size, max_allowed_bytes = 41
        expect(value_sets.size).to eq(2)
      end
    end

    context "when the max allowed bytes is 48 and the base SQL is 26 bytes" do
      it "should return 2 value sets when given 2 value sets of 7 bytes a piece" do
        value_sets = adapter.get_insert_value_sets values, base_sql.size, max_allowed_bytes = 48
        expect(value_sets.size).to eq(2)
      end
    end

    context "when the max allowed bytes is 49 and the base SQL is 26 bytes" do
      it "should return 1 value sets when given 1 value sets of 7 bytes a piece" do
        value_sets = adapter.get_insert_value_sets values, base_sql.size, max_allowed_bytes = 49
        expect(value_sets.size).to eq(1)
      end
    end

    context "when the max allowed bytes is 999999 and the base SQL is 26 bytes" do
      it "should return 1 value sets when given 1 value sets of 7 bytes a piece" do
        value_sets = adapter.get_insert_value_sets values, base_sql.size, max_allowed_bytes = 999999
        expect(value_sets.size).to eq(1)
      end
    end
  end

end

describe "ActiveRecord::Import DB-specific adapter class" do
  context "when ActiveRecord::Import is in use" do
    it "should appear in the AR connection adapter class's ancestors" do
      connection = ActiveRecord::Base.connection
      import_class_name = 'ActiveRecord::Import::' + connection.class.name.demodulize
      expect(connection.class.ancestors).to include(import_class_name.constantize)
    end
  end
end
