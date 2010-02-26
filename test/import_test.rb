require File.expand_path(File.dirname(__FILE__) + '/test_helper')

describe "#import" do
  context "with :validation option" do
    let(:columns) { %w(title author_name) }
    let(:valid_values) { [[ "LDAP", "Jerry Carter"], ["Rails Recipes", "Chad Fowler"]] }
    let(:invalid_values) { [[ "The RSpec Book", ""], ["Agile+UX", ""]] }
  
    context "with validation checks turned off" do
      it "should import valid data" do
        assert_difference "Topic.count", +2 do
          Topic.import columns, valid_values, :validate => false
        end
      end
  
      it "should import invalid data" do
        assert_difference "Topic.count", +2 do
          Topic.import columns, invalid_values, :validate => false
        end
      end
    end
  
    context "with validation checks turned on" do
      it "should import valid data" do
        assert_difference "Topic.count", +2 do
          Topic.import columns, valid_values, :validate => true
        end
      end
  
      it "should not import invalid data" do
        assert_no_difference "Topic.count" do
          Topic.import columns, invalid_values, :validate => true
        end
      end
    
      it "should import valid data when mixed with invalid data" do
        assert_difference "Topic.count", +2 do
          Topic.import columns, valid_values + invalid_values, :validate => true
        end
        assert_equal 0, Topic.find_all_by_title(invalid_values.map(&:first)).count
      end
    end
  end
end
  #   
  #   context "with an array of model instances" do
  #     it "should import attributes from those model instances"
  #     
  #     it "should import unsaved model instances"
  #   end
  #   
  #   context "ActiveRecord model niceties" do
  #     context "created_on columns" do
  #       it "should set the created_on column"
  #       
  #       it "should set the created_on column respecting the time zone"
  #     end
  # 
  #     context "created_at columns" do
  #       it "should set the created_at column"
  #       
  #       it "should set the created_at column respecting the time zone"
  #     end
  # 
  #     context "updated_on columns" do
  #       it "should set the updated_on column"
  #       
  #       it "should set the updated_on column respecting the time zone"
  #     end
  # 
  #     context "updated_at columns" do
  #       it "should set the updated_at column"
  #       
  #       it "should set the updated_at column respecting the time zone"
  #     end
  #   end
  #   
  #   context "importing over existing records" do
  #     it "should not add duplicate records"
  #     
  #     it "should not overwrite existing records"
  #   end
  #   
  #   it "should import models with attribute fields that are database reserved words"
  #   
  #   it "should return the number of inserts performed"
  # end
  # 
  # describe "computing insert value sets" do
  #   context "when the max allowed bytes is 33 and the base SQL is 26 bytes" do
  #     it "should return 3 value sets when given 3 value sets of 7 bytes a piece"
  #   end
  # 
  #   context "when the max allowed bytes is 40 and the base SQL is 26 bytes" do
  #     it "should return 3 value sets when given 3 value sets of 7 bytes a piece"
  #   end
  # 
  #   context "when the max allowed bytes is 41 and the base SQL is 26 bytes" do
  #     it "should return 3 value sets when given 2 value sets of 7 bytes a piece"
  #   end
  # 
  #   context "when the max allowed bytes is 48 and the base SQL is 26 bytes" do
  #     it "should return 3 value sets when given 2 value sets of 7 bytes a piece"
  #   end
  # 
  #   context "when the max allowed bytes is 49 and the base SQL is 26 bytes" do
  #     it "should return 3 value sets when given 1 value sets of 7 bytes a piece"
  #   end
  # 
  #   context "when the max allowed bytes is 999999 and the base SQL is 26 bytes" do
  #     it "should return 3 value sets when given 1 value sets of 7 bytes a piece"
  #   end
  # end
# end