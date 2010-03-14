require File.expand_path(File.dirname(__FILE__) + '/../test_helper')
require "ar-extensions/import/mysql"

describe "#import with :on_duplicate_key_update option (mysql specific functionality)" do
  macro(:perform_import){ raise "supply your own #perform_import in a context below" }
  
  assertion(:should_not_update_fields_not_mentioned) do
    assert_equal "John Doe", @topic.reload.author_name
  end
  
  assertion(:should_update_fields_mentioned) do
    perform_import
    assert_equal "Book - 2nd Edition", @topic.reload.title
    assert_equal "johndoe@example.com", @topic.reload.author_email_address
  end
  
  assertion(:should_update_fields_mentioned_with_hash_mappings) do
    perform_import
    assert_equal "johndoe@example.com", @topic.reload.title
    assert_equal "Book - 2nd Edition", @topic.reload.author_email_address
  end
  
  assertion(:should_update_foreign_keys) do
    perform_import
    assert_equal 57, @topic.reload.parent_id
  end
  
  context "given columns and values with :validation checks turned off" do
    let(:columns){  %w( id title author_name author_email_address parent_id ) }
    let(:values){ [ [ 99, "Book", "John Doe", "john@doe.com", 17 ] ] }
    let(:updated_values){ [ [ 99, "Book - 2nd Edition", "Author Should Not Change", "johndoe@example.com", 57 ] ] }
  
    macro(:perform_import) do
      Topic.import columns, updated_values, :on_duplicate_key_update => update_columns, :validate => false
    end
    
    setup do
      Topic.import columns, values, :validate => false
      @topic = Topic.find 99
    end
    
    context "using string column names" do
      let(:update_columns){ [ "title", "author_email_address", "parent_id" ] }
      should_not_update_fields_not_mentioned
      should_update_fields_mentioned
      should_update_foreign_keys
    end
  
    context "using symbol column names" do
      let(:update_columns){ [ :title, :author_email_address, :parent_id ] }
      should_not_update_fields_not_mentioned
      should_update_fields_mentioned
      should_update_foreign_keys
    end
    
    context "using string hash map" do
      let(:update_columns){ { "title" => "title", "author_email_address" => "author_email_address", "parent_id" => "parent_id" } }
      should_not_update_fields_not_mentioned
      should_update_fields_mentioned
      should_update_foreign_keys
    end
  
    context "using string hash map, but specifying column mismatches" do
      let(:update_columns){ { "title" => "author_email_address", "author_email_address" => "title", "parent_id" => "parent_id" } }
      should_not_update_fields_not_mentioned
      should_update_fields_mentioned_with_hash_mappings
      should_update_foreign_keys
    end
  
    context "using symbol hash map" do
      let(:update_columns){ { :title => :title, :author_email_address => :author_email_address, :parent_id => :parent_id } }
      should_not_update_fields_not_mentioned
      should_update_fields_mentioned
      should_update_foreign_keys
    end
  
    context "using symbol hash map, but specifying column mismatches" do
      let(:update_columns){ { :title => :author_email_address, :author_email_address => :title, :parent_id => :parent_id } }
      should_not_update_fields_not_mentioned
      should_update_fields_mentioned_with_hash_mappings
      should_update_foreign_keys
    end
  end
  
  context "given array of model instances with :validation checks turned off" do
    macro(:perform_import) do
      @topic.title = "Book - 2nd Edition"
      @topic.author_name = "Author Should Not Change"
      @topic.author_email_address = "johndoe@example.com"
      @topic.parent_id = 57
      Topic.import [@topic], :on_duplicate_key_update => update_columns, :validate => false
    end
    
    setup do
      @topic = Generate(:topic, :id => 99, :author_name => "John Doe", :parent_id => 17)
    end
    
    context "using string column names" do
      let(:update_columns){ [ "title", "author_email_address", "parent_id" ] }
      should_not_update_fields_not_mentioned
      should_update_fields_mentioned
      should_update_foreign_keys
    end

    context "using symbol column names" do
      let(:update_columns){ [ :title, :author_email_address, :parent_id ] }
      should_not_update_fields_not_mentioned
      should_update_fields_mentioned
      should_update_foreign_keys
    end
    
    context "using string hash map" do
      let(:update_columns){ { "title" => "title", "author_email_address" => "author_email_address", "parent_id" => "parent_id" } }
      should_not_update_fields_not_mentioned
      should_update_fields_mentioned
      should_update_foreign_keys
    end

    context "using string hash map, but specifying column mismatches" do
      let(:update_columns){ { "title" => "author_email_address", "author_email_address" => "title", "parent_id" => "parent_id" } }
      should_not_update_fields_not_mentioned
      should_update_fields_mentioned_with_hash_mappings
      should_update_foreign_keys
    end

    context "using symbol hash map" do
      let(:update_columns){ { :title => :title, :author_email_address => :author_email_address, :parent_id => :parent_id } }
      should_not_update_fields_not_mentioned
      should_update_fields_mentioned
      should_update_foreign_keys
    end

    context "using symbol hash map, but specifying column mismatches" do
      let(:update_columns){ { :title => :author_email_address, :author_email_address => :title, :parent_id => :parent_id } }
      should_not_update_fields_not_mentioned
      should_update_fields_mentioned_with_hash_mappings
      should_update_foreign_keys
    end
  end
  
end