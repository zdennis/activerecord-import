ActiveRecord::Schema.define do
  create_table :alarms, force: true do |t|
    t.column :device_id, :integer, null: false
    t.column :alarm_type, :integer, null: false
    t.column :status, :integer, null: false
    t.column :metadata, :json, null: false, default: {}
    t.datetime :created_at
    t.datetime :updated_at
  end

  add_index :alarms, [:device_id, :alarm_type], unique: true, where: 'status <> 0',
    name: 'uk_active_by_device_and_type'
end
