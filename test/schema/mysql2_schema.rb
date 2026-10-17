# frozen_string_literal: true

ActiveRecord::Schema.define do
  create_table :books, force: :cascade do |t|
    t.string :title, null: false
    t.virtual :upper_title, type: :string, as: "upper(`title`)" if t.respond_to?(:virtual)
    t.string :publisher, null: false, default: 'Default Publisher'
    t.string :author_name, null: false
    t.datetime :created_at
    t.datetime :created_on
    t.datetime :updated_at
    t.datetime :updated_on
    t.date :publish_date
    t.integer :topic_id
    t.integer :tag_id
    t.integer :publisher_id
    t.boolean :for_sale, default: true
    t.integer :status, default: 0
    t.integer :cover
    t.string :type
  end

  unless ENV["SKIP_COMPOSITE_PK"]
    create_table :authors, force: :cascade do |t|
      t.string :name
    end

    execute "DROP TABLE IF EXISTS composite_books"
    execute <<~SQL
      CREATE TABLE composite_books (
        id bigint NOT NULL AUTO_INCREMENT,
        title varchar(255),
        author_id bigint NOT NULL,
        PRIMARY KEY (id, author_id)
      )
    SQL
  end

  create_table :composite_chapters, force: :cascade do |t|
    t.string :title
    t.integer :composite_book_id, null: false
    t.integer :author_id, null: false
    t.datetime :created_at
    t.datetime :updated_at
  end
end
