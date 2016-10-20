ActiveRecord::Schema.define do
  execute('CREATE extension IF NOT EXISTS "hstore";')
  execute('CREATE extension IF NOT EXISTS "uuid-ossp";')

  create_table :vendors, id: :uuid, force: :cascade do |t|
    t.string :name, null: true
    t.text :preferences

    if t.respond_to?(:json)
      t.json :data
    else
      t.text :data
    end

    if t.respond_to?(:hstore)
      t.hstore :config
    else
      t.text :config
    end

    if t.respond_to?(:jsonb)
      t.jsonb :settings
    else
      t.text :settings
    end

    t.datetime :created_at
    t.datetime :updated_at
  end

  create_table :alarms, force: true do |t|
    t.column :device_id, :integer, null: false
    t.column :alarm_type, :integer, null: false
    t.column :status, :integer, null: false
    t.column :metadata, :text
    t.datetime :created_at
    t.datetime :updated_at
  end

  add_index :alarms, [:device_id, :alarm_type], unique: true, where: 'status <> 0'
end
