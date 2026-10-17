# frozen_string_literal: true

require File.expand_path("#{File.dirname(__FILE__)}/../test_helper")
require 'open3'

# This test starts a new Ruby process, which is slow on JRuby, and only needs
# one adapter. It lives here so that only test:sqlite3 runs it.

describe "requiring activerecord-import after the connection is established" do
  # Establishes and uses the connection before activerecord-import is loaded,
  # so its establish_connection hook never loads the adapter's import support.
  let(:script) do
    <<-RUBY
      require "logger"
      require "active_record"

      ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
      ActiveRecord::Base.connection.create_table(:widgets) do |t|
        t.string :name
        t.integer :count
      end
      ActiveRecord::Base.connection.add_index(:widgets, :name, unique: true)

      require "activerecord-import"

      class Widget < ActiveRecord::Base; end

      warnings = []
      Widget.logger = Logger.new(nil)
      Widget.logger.define_singleton_method(:warn) { |message = nil| warnings << message }

      inserts = 0
      ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
        inserts += 1 if payload[:sql].start_with?("INSERT")
      end

      Widget.import [:name, :count], [["a", 1], ["b", 1], ["c", 1]]
      Widget.import [:name, :count], [["a", 2], ["b", 2]], on_duplicate_key_update: { conflict_target: [:name], columns: [:count] }

      print [inserts, Widget.order(:name).pluck(:name, :count), warnings].inspect
    RUBY
  end

  it "loads the adapter's import support and imports in bulk" do
    lib = File.expand_path('../../../lib', __FILE__)
    out, err, status = Open3.capture3(RbConfig.ruby, "-I", lib, "-rbundler/setup", "-e", script)
    assert status.success?, err
    assert_equal [2, [["a", 2], ["b", 2], ["c", 1]], []].inspect, out
  end
end
