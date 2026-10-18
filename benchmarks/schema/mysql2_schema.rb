# frozen_string_literal: true

ActiveRecord::Schema.define do
  # MEMORY tables are capped at max_heap_table_size (16MB by default) when they're created,
  # which is too small for larger benchmarks.
  execute "SET SESSION max_heap_table_size = #{1024 * 1024 * 1024}"

  create_table :test_myisam, options: 'ENGINE=MyISAM', force: true do |t|
    t.column :my_name, :string, null: false
    t.column :description, :string
  end

  create_table :test_innodb, options: 'ENGINE=InnoDb', force: true do |t|
    t.column :my_name, :string, null: false
    t.column :description, :string
  end

  create_table :test_memory, options: 'ENGINE=Memory', force: true do |t|
    t.column :my_name, :string, null: false
    t.column :description, :string
  end
end
