# frozen_string_literal: true

module ActiveRecord::Import
  # Methods aliased to +bulk_import+ and +bulk_import!+, keyed by the class
  # they're defined on.
  ALIASES = {
    ActiveRecord::Associations::CollectionProxy => { import: :bulk_import },
    ActiveRecord::Associations::CollectionAssociation => { import: :bulk_import },
    ActiveRecord::Base.singleton_class => { import: :bulk_import, import!: :bulk_import! }
  }.freeze

  # Aliases +import+ and +import!+ to +bulk_import+ and +bulk_import!+, unless
  # they are already defined or aliases have been skipped.
  def self.define_aliases
    return if skip_aliases?

    ALIASES.each do |klass, aliases|
      aliases.each do |name, target|
        klass.send(:alias_method, name, target) unless klass.method_defined?(name)
      end
    end
  end

  # Prevents the +import+ and +import!+ aliases from being defined, and removes
  # them if they already have been. Used by "activerecord-import/without_aliases".
  def self.skip_aliases!
    @skip_aliases = true

    ALIASES.each do |klass, aliases|
      aliases.each do |name, target|
        next unless klass.method_defined?(name)

        method = klass.instance_method(name)
        klass.send(:remove_method, name) if method.owner == klass && method.original_name == target
      end
    end
  end

  def self.skip_aliases?
    @skip_aliases == true
  end
end
