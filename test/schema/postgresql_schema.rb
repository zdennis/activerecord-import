ActiveRecord::Schema.define do
  execute('CREATE extension IF NOT EXISTS "uuid-ossp";')

  create_table :vendors, id: :uuid, force: :cascade do |t|
    t.string :name, null: true
    t.datetime :created_at
    t.datetime :updated_at
  end
end
