# frozen_string_literal: true

require File.expand_path("#{File.dirname(__FILE__)}/../test_helper")
require 'open3'

# These tests don't use the database, and each one starts a new Ruby process,
# which is slow on JRuby. They live here so that only test:sqlite3 runs them,
# rather than every adapter's tests.

describe "loading activerecord-import" do
  let(:aliased) { "[true, true, true, true, true, :bulk_import]" }
  let(:not_aliased) { "[true, false, false, false, false, :import]" }

  let(:load_base_first) { false }

  # Mimics elasticsearch-model, which only defines +import+ on a model when
  # the model doesn't already respond to it.
  let(:script) do
    <<-RUBY
      require "logger"
      require "active_record"
      ActiveRecord::Base if #{load_base_first}
      #{entry_points.map { |entry_point| "require #{entry_point.inspect}" }.join("\n")}

      module SearchImport
        def self.included(base)
          base.singleton_class.class_eval do
            define_method(:import) { :search_import } unless public_instance_methods.include?(:import)
          end
        end
      end

      class Thing < ActiveRecord::Base
        include SearchImport
      end

      print [
        ActiveRecord::Base.respond_to?(:bulk_import),
        ActiveRecord::Base.respond_to?(:import),
        ActiveRecord::Base.respond_to?(:import!),
        ActiveRecord::Associations::CollectionProxy.method_defined?(:import),
        ActiveRecord::Associations::CollectionAssociation.method_defined?(:import),
        Thing.method(:import).original_name
      ].inspect
    RUBY
  end

  let(:output) do
    lib = File.expand_path('../../../lib', __FILE__)
    out, err, status = Open3.capture3(RbConfig.ruby, "-I", lib, "-rbundler/setup", "-e", script)
    assert status.success?, err
    out
  end

  describe "with activerecord-import" do
    let(:entry_points) { %w(activerecord-import) }

    it "aliases import to bulk_import" do
      assert_equal aliased, output
    end
  end

  describe "with activerecord-import/base" do
    let(:entry_points) { %w(activerecord-import/base) }
    let(:load_base_first) { true }

    it "aliases import to bulk_import" do
      assert_equal aliased, output
    end
  end

  describe "with activerecord-import/without_aliases" do
    let(:entry_points) { %w(activerecord-import/without_aliases) }

    it "does not alias import to bulk_import" do
      assert_equal not_aliased, output
    end
  end

  [false, true].each do |base_loaded|
    describe "with ActiveRecord::Base #{base_loaded ? 'already' : 'not yet'} loaded" do
      let(:load_base_first) { base_loaded }

      describe "when activerecord-import is required before activerecord-import/without_aliases" do
        let(:entry_points) { %w(activerecord-import activerecord-import/without_aliases) }

        it "removes the aliases" do
          assert_equal not_aliased, output
        end
      end

      describe "when activerecord-import is required after activerecord-import/without_aliases" do
        let(:entry_points) { %w(activerecord-import/without_aliases activerecord-import) }

        it "does not alias import to bulk_import" do
          assert_equal not_aliased, output
        end
      end
    end
  end
end
