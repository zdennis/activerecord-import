ActiveRecord::Schema.define do
  create_table :schema_info, force: :cascade do |t|
    t.integer :version, unique: true
  end
  SchemaInfo.create version: SchemaInfo::VERSION

  create_table :group, force: :cascade do |t|
    t.string :order
    t.timestamps null: true
  end

  create_table :topics, force: :cascade do |t|
    t.string :title, null: false
    t.string :author_name
    t.string :author_email_address
    t.datetime :written_on
    t.time :bonus_time
    t.datetime :last_read
    t.text :content
    t.boolean :approved, default: '1'
    t.integer :replies_count
    t.integer :parent_id
    t.string :type
    t.datetime :created_at
    t.datetime :created_on
    t.datetime :updated_at
    t.datetime :updated_on
  end

  create_table :projects, force: :cascade do |t|
    t.string :name
    t.string :type
  end

  create_table :developers, force: :cascade do |t|
    t.string :name
    t.integer :salary, default: '70000'
    t.datetime :created_at
    t.integer :team_id
    t.datetime :updated_at
  end

  create_table :addresses, force: :cascade do |t|
    t.string :address
    t.string :city
    t.string :state
    t.string :zip
    t.integer :developer_id
  end

  create_table :teams, force: :cascade do |t|
    t.string :name
  end

  create_table :books, force: :cascade do |t|
    t.string :title, null: false
    t.string :publisher, null: false, default: 'Default Publisher'
    t.string :author_name, null: false
    t.datetime :created_at
    t.datetime :created_on
    t.datetime :updated_at
    t.datetime :updated_on
    t.date :publish_date
    t.integer :topic_id
    t.boolean :for_sale, default: true
    t.integer :status, default: 0
  end

  create_table :chapters, force: :cascade do |t|
    t.string :title
    t.integer :book_id, null: false
    t.datetime :created_at
    t.datetime :updated_at
  end

  create_table :end_notes, force: :cascade do |t|
    t.string :note
    t.integer :book_id, null: false
    t.datetime :created_at
    t.datetime :updated_at
  end

  create_table :languages, force: :cascade do |t|
    t.string :name
    t.integer :developer_id
  end

  create_table :shopping_carts, force: :cascade do |t|
    t.string :name, null: true
    t.datetime :created_at
    t.datetime :updated_at
  end

  create_table :cart_items, force: :cascade do |t|
    t.string :shopping_cart_id, null: false
    t.string :book_id, null: false
    t.integer :copies, default: 1
    t.datetime :created_at
    t.datetime :updated_at
  end

  add_index :cart_items, [:shopping_cart_id, :book_id], unique: true, name: 'uk_shopping_cart_books'

  create_table :animals, force: :cascade do |t|
    t.string :name, null: false
    t.string :size, default: nil
    t.datetime :created_at
    t.datetime :updated_at
  end

  add_index :animals, [:name], unique: true, name: 'uk_animals'

  create_table :widgets, id: false, force: :cascade do |t|
    t.integer :w_id
    t.boolean :active, default: false
    t.text :data
    t.text :json_data
  end

  create_table :promotions, primary_key: :promotion_id, force: :cascade do |t|
    t.string :code
    t.string :description
    t.decimal :discount
  end

  add_index :promotions, [:code], unique: true, name: 'uk_code'

  create_table :discounts, force: :cascade do |t|
    t.decimal :amount
    t.integer :discountable_id
    t.string :discountable_type
  end

  create_table :rules, force: :cascade do |t|
    t.string :condition_text
    t.integer :question_id
  end

  create_table :questions, force: :cascade do |t|
    t.string :body
  end
end
