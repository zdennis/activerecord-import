# frozen_string_literal: true

module ActiveRecord::Import::ConnectionAdapters; end

module ActiveRecord::Import # :nodoc:
  Result = Struct.new(:failed_instances, :num_inserts, :ids, :results, :affected_rows)

  module ImportSupport # :nodoc:
    def supports_import? # :nodoc:
      true
    end
  end

  module OnDuplicateKeyUpdateSupport # :nodoc:
    def supports_on_duplicate_key_update? # :nodoc:
      true
    end
  end

  class MissingColumnError < StandardError
    def initialize(name, index)
      super "Missing column for value <#{name}> at index #{index}"
    end
  end

  # Skips uniqueness validations while a model is being validated for an import
  # that doesn't validate uniqueness, including the validations Rails runs on
  # the model's associated records.
  module SkipUniquenessValidation # :nodoc:
    def validate_each(record, attribute, value)
      super unless ActiveRecord::Import::Validator.skip_uniqueness?
    end
  end

  # Validates the presence of a belongs_to association on a model being
  # validated for an import by checking its foreign key, so the associated
  # record isn't loaded for every model.
  module ForeignKeyPresenceValidation # :nodoc:
    def validate(record)
      validator = ActiveRecord::Import::Validator.foreign_key_presence_validator(self, record)
      return super unless validator

      ActiveModel::EachValidator.instance_method(:validate).bind(validator).call(record)
    end
  end

  class Validator
    # Holds [validator, model] for the current thread while valid_model? runs.
    CURRENT = :activerecord_import_validation

    attr_reader :options

    def self.skip_uniqueness?
      validator, = Thread.current[CURRENT]
      validator ? !validator.options[:validate_uniqueness] : false
    end

    def self.foreign_key_presence_validator(presence_validator, record)
      validator, model = Thread.current[CURRENT]
      validator.foreign_key_presence_validator(presence_validator, record.class) if model.equal?(record)
    end

    def initialize(options = {})
      @options = options
      @foreign_key_presence_validators = {}
    end

    def valid_model?(model)
      current = Thread.current[CURRENT]
      Thread.current[CURRENT] = [self, model]
      model.valid?(@options[:validate_with_context])
    ensure
      Thread.current[CURRENT] = current
    end

    # Returns a copy of +presence_validator+ that validates the foreign keys of
    # any belongs_to associations it validates, or nil if there are none.
    def foreign_key_presence_validator(presence_validator, klass)
      key = [presence_validator, klass]
      return @foreign_key_presence_validators[key] if @foreign_key_presence_validators.key?(key)

      attrs = presence_validator.attributes.dup
      klass.reflect_on_all_associations(:belongs_to).each do |assoc|
        if (index = attrs.index(assoc.name))
          foreign_key = assoc.foreign_key.is_a?(Array) ? assoc.foreign_key.map(&:to_sym) : assoc.foreign_key.to_sym
          attrs[index] = foreign_key unless attrs.include?(foreign_key)
        end
      end

      @foreign_key_presence_validators[key] = if attrs != presence_validator.attributes
        presence_validator.dup.tap { |validator| validator.instance_variable_set(:@attributes, attrs.flatten) }
      end
    end
  end
end

ActiveRecord::Validations::UniquenessValidator.prepend(ActiveRecord::Import::SkipUniquenessValidation)
ActiveModel::Validations::PresenceValidator.prepend(ActiveRecord::Import::ForeignKeyPresenceValidation)

class ActiveRecord::Associations::CollectionProxy
  def bulk_import(*args, &block)
    @association.bulk_import(*args, &block)
  end
end

class ActiveRecord::Associations::CollectionAssociation
  def bulk_import(*args, &block)
    unless owner.persisted?
      raise ActiveRecord::RecordNotSaved, "You cannot call import unless the parent is saved"
    end

    options = args.last.is_a?(Hash) ? args.pop : {}

    model_klass = reflection.klass
    args = model_klass.send(:arrays_from_array_like_import_arguments, args)
    symbolized_foreign_key = reflection.foreign_key.to_sym

    symbolized_column_names = if model_klass.connection_pool.with_connection(&:supports_virtual_columns?)
      model_klass.columns.reject(&:virtual?).map { |c| c.name.to_sym }
    else
      model_klass.column_names.map(&:to_sym)
    end

    owner_primary_key = reflection.active_record_primary_key.to_sym
    owner_primary_key_value = owner.send(owner_primary_key)
    owner_polymorphic_name = owner.class.polymorphic_name if reflection.type

    # assume array of model objects
    if args.last.is_a?( Array ) && args.last.first.is_a?(ActiveRecord::Base)
      if args.length == 2
        models = args.last
        column_names = args.first.dup
        symbolized_column_names = column_names.map(&:to_sym)
      else
        models = args.first
        column_names = symbolized_column_names
      end

      unless symbolized_column_names.include?(symbolized_foreign_key)
        column_names << symbolized_foreign_key
      end

      if reflection.type && !symbolized_column_names.include?(reflection.type.to_sym)
        column_names << reflection.type.to_sym
      end

      models.each do |m|
        m.public_send "#{symbolized_foreign_key}=", owner_primary_key_value
        m.public_send "#{reflection.type}=", owner_polymorphic_name if reflection.type
      end

      model_klass.bulk_import column_names, models, options

    # supports array of hash objects
    elsif args.last.is_a?( Array ) && args.last.first.is_a?(Hash)
      if args.length == 2
        array_of_hashes = args.last
        column_names = args.first.dup
        allow_extra_hash_keys = true
      else
        array_of_hashes = args.first
        column_names = array_of_hashes.first.keys
        allow_extra_hash_keys = false
      end

      required_column_names = column_names.dup
      symbolized_column_names = column_names.map(&:to_sym)
      unless symbolized_column_names.include?(symbolized_foreign_key)
        column_names << symbolized_foreign_key
      end

      if reflection.type && !symbolized_column_names.include?(reflection.type.to_sym)
        column_names << reflection.type.to_sym
      end

      array_of_attributes = array_of_hashes.map do |h|
        error_message = model_klass.send(:validate_hash_import, h, required_column_names, allow_extra_hash_keys)

        raise ArgumentError, error_message if error_message

        column_names.map do |key|
          symbolized_key = key.to_sym
          if symbolized_key == symbolized_foreign_key
            owner_primary_key_value
          elsif reflection.type && symbolized_key == reflection.type.to_sym
            owner_polymorphic_name
          else
            h[key]
          end
        end
      end

      model_klass.bulk_import column_names, array_of_attributes, options

    # supports empty array
    elsif args.last.is_a?( Array ) && args.last.empty?
      ActiveRecord::Import::Result.new([], 0, [])

    # supports 2-element array and array
    elsif args.size == 2 && args.first.is_a?( Array ) && args.last.is_a?( Array )
      column_names, array_of_attributes = args

      # dup the passed args so we don't modify unintentionally
      column_names = column_names.dup
      array_of_attributes = array_of_attributes.map(&:dup)

      symbolized_column_names = column_names.map(&:to_sym)

      if symbolized_column_names.include?(symbolized_foreign_key)
        index = symbolized_column_names.index(symbolized_foreign_key)
        array_of_attributes.each { |attrs| attrs[index] = owner_primary_key_value }
      else
        column_names << symbolized_foreign_key
        array_of_attributes.each { |attrs| attrs << owner_primary_key_value }
      end

      if reflection.type
        symbolized_type = reflection.type.to_sym
        if symbolized_column_names.include?(symbolized_type)
          index = symbolized_column_names.index(symbolized_type)
          array_of_attributes.each { |attrs| attrs[index] = owner_polymorphic_name }
        else
          column_names << symbolized_type
          array_of_attributes.each { |attrs| attrs << owner_polymorphic_name }
        end
      end

      model_klass.bulk_import column_names, array_of_attributes, options
    else
      raise ArgumentError, model_klass.send(:invalid_import_arguments_message, args)
    end
  end
end

module ActiveRecord::Import::ConnectionHandler
  def establish_connection(*args, **kwargs, &block)
    pool = super(*args, **kwargs, &block)
    ActiveRecord::Import.load_from_connection_pool pool
    pool
  end
end

class ActiveRecord::ConnectionAdapters::ConnectionHandler
  prepend ActiveRecord::Import::ConnectionHandler
end

class ActiveRecord::Base
  class << self
    # Returns true if the current database connection adapter
    # supports import functionality, otherwise returns false.
    def supports_import?(conn = nil)
      if conn
        conn.respond_to?(:supports_import?) && conn.supports_import?
      else
        connection_pool.with_connection do |conn|
          conn.respond_to?(:supports_import?) && conn.supports_import?
        end
      end
    end

    # Returns true if the current database connection adapter
    # supports on duplicate key update functionality, otherwise
    # returns false.
    def supports_on_duplicate_key_update?(conn = nil)
      if conn
        conn.respond_to?(:supports_on_duplicate_key_update?) && conn.supports_on_duplicate_key_update?
      else
        connection_pool.with_connection do |conn|
          conn.respond_to?(:supports_on_duplicate_key_update?) && conn.supports_on_duplicate_key_update?
        end
      end
    end

    # returns true if the current database connection adapter
    # supports setting the primary key of bulk imported models, otherwise
    # returns false
    def supports_setting_primary_key_of_imported_objects?(conn = nil)
      if conn
        conn.respond_to?(:supports_setting_primary_key_of_imported_objects?) && conn.supports_setting_primary_key_of_imported_objects?
      else
        connection_pool.with_connection do |conn|
          conn.respond_to?(:supports_setting_primary_key_of_imported_objects?) && conn.supports_setting_primary_key_of_imported_objects?
        end
      end
    end

    # Imports a collection of values to the database.
    #
    # This is more efficient than using ActiveRecord::Base#create or
    # ActiveRecord::Base#save multiple times. This method works well if
    # you want to create more than one record at a time and do not care
    # about having ActiveRecord objects returned for each record
    # inserted.
    #
    # This can be used with or without validations. It does not utilize
    # the ActiveRecord::Callbacks during creation/modification while
    # performing the import.
    #
    # == Usage
    #  Model.import array_of_models
    #  Model.import column_names, array_of_models
    #  Model.import array_of_hash_objects
    #  Model.import column_names, array_of_hash_objects
    #  Model.import column_names, array_of_values
    #  Model.import column_names, array_of_values, options
    #
    # ==== Model.import array_of_models
    #
    # With this form you can call _import_ passing in an array of model
    # objects that you want updated.
    #
    # ==== Model.import column_names, array_of_values
    #
    # The first parameter +column_names+ is an array of symbols or
    # strings which specify the columns that you want to update.
    #
    # The second parameter, +array_of_values+, is an array of
    # arrays. Each subarray is a single set of values for a new
    # record. The order of values in each subarray should match up to
    # the order of the +column_names+.
    #
    # ==== Model.import column_names, array_of_values, options
    #
    # The first two parameters are the same as the above form. The third
    # parameter, +options+, is a hash. This is optional. Please see
    # below for what +options+ are available.
    #
    # == Options
    # * +validate+ - true|false, tells import whether or not to use
    #   ActiveRecord validations. Validations are enforced by default.
    #   It skips the uniqueness validation for performance reasons.
    #   You can find more details here:
    #   https://github.com/zdennis/activerecord-import/issues/228
    # * +ignore+ - true|false, an alias for on_duplicate_key_ignore.
    # * +on_duplicate_key_ignore+ - true|false, tells import to discard
    #   records that contain duplicate keys. For Postgres 9.5+ it adds
    #   ON CONFLICT DO NOTHING, for MySQL it uses INSERT IGNORE, and for
    #   SQLite it uses INSERT OR IGNORE. Cannot be enabled on a
    #   recursive import. For database adapters that normally support
    #   setting primary keys on imported objects, this option prevents
    #   that from occurring.
    # * +on_duplicate_key_update+ - :all, an Array, or Hash, tells import to
    #   use MySQL's ON DUPLICATE KEY UPDATE or Postgres/SQLite ON CONFLICT
    #   DO UPDATE ability. See On Duplicate Key Update below.
    # * +synchronize+ - an array of ActiveRecord instances for the model
    #   that you are currently importing data into. This synchronizes
    #   existing model instances in memory with updates from the import.
    # * +timestamps+ - true|false, tells import to not add timestamps
    #   (if false) even if record timestamps is disabled in ActiveRecord::Base
    # * +recursive+ - true|false, tells import to import all has_many/has_one
    #   associations if the adapter supports setting the primary keys of the
    #   newly imported objects. PostgreSQL and MariaDB 10.5+ only.
    # * +batch_size+ - an integer value to specify the max number of records to
    #   include per insert. Defaults to the total number of records to import.
    #
    # == Examples
    #  class BlogPost < ActiveRecord::Base ; end
    #
    #  # Example using array of model objects
    #  posts = [ BlogPost.new author_name: 'Zach Dennis', title: 'AREXT',
    #            BlogPost.new author_name: 'Zach Dennis', title: 'AREXT2',
    #            BlogPost.new author_name: 'Zach Dennis', title: 'AREXT3' ]
    #  BlogPost.import posts
    #
    #  # Example using array_of_hash_objects
    #  # NOTE: column_names will be determined by using the keys of the first hash in the array. If later hashes in the
    #  # array have different keys an exception will be raised. If you have hashes to import with different sets of keys
    #  # we recommend grouping these into batches before importing.
    #  values = [ {author_name: 'zdennis', title: 'test post'} ], [ {author_name: 'jdoe', title: 'another test post'} ] ]
    #  BlogPost.import values
    #
    #  # Example using column_names and array_of_hash_objects
    #  columns = [ :author_name, :title ]
    #  values = [ {author_name: 'zdennis', title: 'test post'} ], [ {author_name: 'jdoe', title: 'another test post'} ] ]
    #  BlogPost.import columns, values
    #
    #  # Example using column_names and array_of_values
    #  columns = [ :author_name, :title ]
    #  values = [ [ 'zdennis', 'test post' ], [ 'jdoe', 'another test post' ] ]
    #  BlogPost.import columns, values
    #
    #  # Example using column_names, array_of_value and options
    #  columns = [ :author_name, :title ]
    #  values = [ [ 'zdennis', 'test post' ], [ 'jdoe', 'another test post' ] ]
    #  BlogPost.import( columns, values, validate: false  )
    #
    #  # Example synchronizing existing instances in memory
    #  post = BlogPost.where(author_name: 'zdennis').first
    #  puts post.author_name # => 'zdennis'
    #  columns = [ :author_name, :title ]
    #  values = [ [ 'yoda', 'test post' ] ]
    #  BlogPost.import posts, synchronize: [ post ]
    #  puts post.author_name # => 'yoda'
    #
    #  # Example synchronizing unsaved/new instances in memory by using a uniqued imported field
    #  posts = [BlogPost.new(title: "Foo"), BlogPost.new(title: "Bar")]
    #  BlogPost.import posts, synchronize: posts, synchronize_keys: [:title]
    #  puts posts.first.persisted? # => true
    #
    # == On Duplicate Key Update (MySQL)
    #
    # The :on_duplicate_key_update option can be either :all, an Array, or a Hash.
    #
    # ==== Using :all
    #
    # The :on_duplicate_key_update option can be set to :all. All columns
    # other than the primary key are updated, except for timestamps recorded
    # on create, such as created_at. If a list of column names is
    # supplied, only those columns will be updated. Below is an example:
    #
    #   BlogPost.import columns, values, on_duplicate_key_update: :all
    #
    # ==== Using an Array
    #
    # The :on_duplicate_key_update option can be an array of column
    # names. The column names are the only fields that are updated if
    # a duplicate record is found. Below is an example:
    #
    #   BlogPost.import columns, values, on_duplicate_key_update: [ :date_modified, :content, :author ]
    #
    # ====  Using A Hash
    #
    # The :on_duplicate_key_update option can be a hash of column names
    # to model attribute name mappings. This gives you finer grained
    # control over what fields are updated with what attributes on your
    # model. Below is an example:
    #
    #   BlogPost.import columns, attributes, on_duplicate_key_update: { title: :title }
    #
    # == On Duplicate Key Update (Postgres 9.5+ and SQLite 3.24+)
    #
    # The :on_duplicate_key_update option can be :all, an Array, or a Hash with up to
    # three attributes, :conflict_target (and optionally :index_predicate) or
    # :constraint_name (Postgres), and :columns.
    #
    # ==== Using :all
    #
    # The :on_duplicate_key_update option can be set to :all. All columns
    # other than the primary key are updated, except for timestamps recorded
    # on create, such as created_at. If a list of column names is
    # supplied, only those columns will be updated. Below is an example:
    #
    #   BlogPost.import columns, values, on_duplicate_key_update: :all
    #
    # ==== Using an Array
    #
    # The :on_duplicate_key_update option can be an array of column
    # names. This option only handles inserts that conflict with the
    # primary key. If a table does not have a primary key, this will
    # not work. The column names are the only fields that are updated
    # if a duplicate record is found. Below is an example:
    #
    #   BlogPost.import columns, values, on_duplicate_key_update: [ :date_modified, :content, :author ]
    #
    # ====  Using a Hash
    #
    # The :on_duplicate_key_update option can be a hash with up to three
    # attributes, :conflict_target (and optionally :index_predicate) or
    # :constraint_name, and :columns. Unlike MySQL, Postgres requires the
    # conflicting constraint to be explicitly specified. Using this option
    # allows you to specify a constraint other than the primary key.
    #
    # ===== :conflict_target
    #
    # The :conflict_target attribute specifies the columns that make up the
    # conflicting unique constraint and can be a single column or an array of
    # column names. This attribute is ignored if :constraint_name is included,
    # but it is the preferred method of identifying a constraint. It will
    # default to the primary key. Below is an example:
    #
    #   BlogPost.import columns, values, on_duplicate_key_update: { conflict_target: [ :author_id, :slug ], columns: [ :date_modified ] }
    #
    # ===== :index_predicate
    #
    # The :index_predicate attribute optionally specifies a WHERE condition
    # on :conflict_target, which is required for matching against partial
    # indexes. This attribute is ignored if :constraint_name is included.
    # Below is an example:
    #
    #   BlogPost.import columns, values, on_duplicate_key_update: { conflict_target: [ :author_id, :slug ], index_predicate: 'status <> 0', columns: [ :date_modified ] }
    #
    # ===== :constraint_name
    #
    # The :constraint_name attribute explicitly identifies the conflicting
    # unique index by name. Postgres documentation discourages using this method
    # of identifying an index unless absolutely necessary. Below is an example:
    #
    #   BlogPost.import columns, values, on_duplicate_key_update: { constraint_name: :blog_posts_pkey, columns: [ :date_modified ] }
    #
    # ===== :condition
    #
    # The :condition attribute optionally specifies a WHERE condition
    # on :conflict_action. Only rows for which this expression returns true will be updated.
    # Note that it's evaluated last, after a conflict has been identified as a candidate to update.
    # Below is an example:
    #
    #   BlogPost.import columns, values, on_duplicate_key_update: { conflict_target: [ :author_id ], condition: "blog_posts.title NOT LIKE '%sample%'", columns: [ :author_name ] }
    #
    # ===== :columns
    #
    # The :columns attribute can be either :all, an Array, or a Hash.
    #
    # ===== Using :all
    #
    # The :columns attribute can be :all. All columns other than the primary key will be updated,
    # except for timestamps recorded on create, such as created_at.
    # If a list of column names is supplied, only those columns will be updated.
    # Below is an example:
    #
    #   BlogPost.import columns, values, on_duplicate_key_update: { conflict_target: :slug, columns: :all }
    #
    # ===== Using an Array
    #
    # The :columns attribute can be an array of column names. The column names
    # are the only fields that are updated if a duplicate record is found.
    # Below is an example:
    #
    #   BlogPost.import columns, values, on_duplicate_key_update: { conflict_target: :slug, columns: [ :date_modified, :content, :author ] }
    #
    # =====  Using a Hash
    #
    # The :columns option can be a hash of column names to model attribute name
    # mappings. This gives you finer grained control over what fields are updated
    # with what attributes on your model. Below is an example:
    #
    #   BlogPost.import columns, attributes, on_duplicate_key_update: { conflict_target: :slug, columns: { title: :title } }
    #
    # = Returns
    # This returns an object which responds to +failed_instances+ and +num_inserts+.
    # * failed_instances - an array of objects that fails validation and were not committed to the database. An empty array if no validation is performed.
    # * num_inserts - the number of insert statements it took to import the data
    # * ids - the primary keys of the imported ids if the adapter supports it, otherwise an empty array.
    # * results - import results if the adapter supports it, otherwise an empty array.
    def bulk_import(*args)
      if args.first.is_a?( Array ) && args.first.first.is_a?(ActiveRecord::Base)
        options = {}
        options.merge!( args.pop ) if args.last.is_a?(Hash)

        models = args.first
        import_helper(models, options)
      else
        import_helper(*args)
      end
    end

    # Imports a collection of values if all values are valid. Import fails at the
    # first encountered validation error and raises ActiveRecord::RecordInvalid
    # with the failed instance.
    def bulk_import!(*args)
      options = args.last.is_a?( Hash ) ? args.pop : {}
      options = options.merge( validate: true, raise_error: true )

      bulk_import(*args, options)
    end

    # Returns the column for +name+, following an attribute alias unless +name+ is
    # itself a column, so a column that's also an alias isn't replaced by the
    # column it aliases.
    def column_name_for_import(name) # :nodoc:
      name = name.to_s
      attribute_alias?(name) && !columns_hash.key?(name) ? attribute_alias(name) : name
    end

    def import_helper( *args )
      connection_pool.with_connection do |conn|
        # The adapter's import support is loaded when the connection is established, which is
        # missed if activerecord-import is required afterwards, so load it now if it's missing.
        ActiveRecord::Import.load_from_connection_pool_once(connection_pool) unless supports_import?(conn)

        options, args = options_and_arguments_for_import(args)

        is_validating = options[:validate_with_context].present? || options[:validate]
        validator = ActiveRecord::Import::Validator.new(options) if is_validating

        # supports empty array
        return ActiveRecord::Import::Result.new([], 0, [], []) if args.last.is_a?( Array ) && args.last.empty?

        # assume array of model objects
        if args.last.is_a?( Array ) && args.last.first.is_a?(ActiveRecord::Base)
          models, column_names, default_column_names = models_and_column_names_for_import(conn, args)
          array_of_attributes = attributes_from_models(conn, models, column_names, validator, options)
        else
          column_names, array_of_attributes = column_names_and_attributes_for_import(args)
        end

        # Rows without a value for these columns get the database's default rather than NULL
        options[:database_default_columns] = Array(default_column_names) | database_populated_primary_keys(conn)

        # Don't modify incoming arguments
        on_duplicate_key_update = options[:on_duplicate_key_update]
        if on_duplicate_key_update
          options[:on_duplicate_key_update] = on_duplicate_key_update_for_import(on_duplicate_key_update, column_names, options)
        end

        add_primary_key_for_sequence(conn, column_names, array_of_attributes)

        timestamps = {}

        # record timestamps unless disabled in ActiveRecord::Base
        if record_timestamps && options[:timestamps]
          timestamps = add_special_rails_stamps conn, column_names, array_of_attributes, options
        end

        return_obj = if is_validating
          import_with_validations( conn, column_names, array_of_attributes, options ) do |failed_instances|
            if models
              add_failed_models(failed_instances, models, options)
            else
              validate_attributes_for_import(failed_instances, column_names, array_of_attributes, validator, options)
            end
          end
        else
          import_without_validations_or_callbacks( conn, column_names, array_of_attributes, options )
        end

        return return_obj if options[:all_or_none] && return_obj.failed_instances.any?

        if options[:synchronize]
          sync_keys = options[:synchronize_keys] || Array(primary_key)
          synchronized_instances = synchronize_imported_instances(options[:synchronize], sync_keys)
        end
        return_obj.num_inserts = 0 if return_obj.num_inserts.nil?

        # if we have ids, then set the id on the models and mark the models as clean.
        if models && supports_setting_primary_key_of_imported_objects?(conn)
          set_attributes_and_mark_clean(conn, models, return_obj, timestamps, options)

          # if there are auto-save associations on the models we imported that are new, import them as well
          if options[:recursive]
            import_associations_of_imported_models(models, return_obj, on_duplicate_key_update, options)
          end
        end

        # apply the changes of synchronized instances that weren't marked clean above,
        # such as when importing columns and values rather than models
        synchronized_instances&.each { |instance| instance.changes_applied if instance.changed? }

        return_obj
      end
    end

    # Imports the passed in +column_names+ and +array_of_attributes+
    # given the passed in +options+ Hash with validations. Returns an
    # object with the methods +failed_instances+ and +num_inserts+.
    # +failed_instances+ is an array of instances that failed validations.
    # +num_inserts+ is the number of inserts it took to import the data. See
    # ActiveRecord::Base.import for more information on
    # +column_names+, +array_of_attributes+ and +options+.
    def import_with_validations( conn, column_names, array_of_attributes, options = {} )
      failed_instances = []

      yield failed_instances if block_given?

      result = if options[:all_or_none] && failed_instances.any?
        ActiveRecord::Import::Result.new([], 0, [], [])
      else
        import_without_validations_or_callbacks( conn, column_names, array_of_attributes, options )
      end
      ActiveRecord::Import::Result.new(failed_instances, result.num_inserts, result.ids, result.results, result.affected_rows)
    end

    # Imports the passed in +column_names+ and +array_of_attributes+
    # given the passed in +options+ Hash. This will return the number
    # of insert operations it took to create these records without
    # validations or callbacks. See ActiveRecord::Base.import for more
    # information on +column_names+, +array_of_attributes_ and
    # +options+.
    def import_without_validations_or_callbacks( conn, column_names, array_of_attributes, options = {} )
      return ActiveRecord::Import::Result.new([], 0, [], []) if array_of_attributes.empty?

      column_names = column_names.map do |name|
        column_name_for_import(name).to_sym
      end
      scope_columns, scope_values = scope_attributes.to_a.transpose

      unless scope_columns.blank?
        scope_columns.zip(scope_values).each do |name, value|
          name_as_sym = name.to_sym
          next if column_names.include?(name_as_sym) || name_as_sym == inheritance_column.to_sym
          column_names << name_as_sym
          array_of_attributes.each { |attrs| attrs << value }
        end
      end

      if finder_needs_type_condition? && !column_names.include?(inheritance_column.to_sym)
        column_names << inheritance_column.to_sym
        array_of_attributes.each { |attrs| attrs << sti_name }
      end

      columns = column_names.each_with_index.map do |name, i|
        column = schema_columns_hash(conn)[name.to_s]
        raise ActiveRecord::Import::MissingColumnError.new(name.to_s, i) if column.nil?
        column
      end

      columns_sql = "(#{column_names.map { |name| conn.quote_column_name(name) }.join(',')})"
      pre_sql_statements = conn.pre_sql_statements( options )
      insert_sql = ['INSERT', pre_sql_statements, "INTO #{quoted_table_name} #{columns_sql} VALUES "]
      insert_sql = insert_sql.flatten.join(' ')
      values_sql = values_sql_for_columns_and_attributes(conn, columns, array_of_attributes, Array(options[:database_default_columns]))
      comment_sql = sql_comment_for_annotations(conn)

      number_inserted = 0
      ids = []
      results = []
      affected_rows = 0

      if supports_import?(conn)
        # generate the sql
        post_sql_statements = conn.post_sql_statements( quoted_table_name, options )
        post_sql_statements += [comment_sql] if comment_sql
        import_size = values_sql.size

        batch_size = options[:batch_size] || import_size
        run_proc = options[:batch_size].to_i.positive? && options[:batch_progress].respond_to?( :call )
        progress_proc = options[:batch_progress]
        current_batch = 0
        batches = (import_size / batch_size.to_f).ceil

        values_sql.each_slice(batch_size) do |batch_values|
          batch_started_at = Time.now.to_i

          # perform the inserts
          result = conn.insert_many( [insert_sql, post_sql_statements].flatten,
            batch_values,
            options,
            "#{model_name} Create Many" )

          number_inserted += result.num_inserts
          ids.concat(result.ids)
          results.concat(result.results)
          affected_rows = result.affected_rows.nil? ? nil : (affected_rows || 0) + result.affected_rows
          current_batch += 1

          progress_proc.call(import_size, batches, current_batch, Time.now.to_i - batch_started_at) if run_proc
        end
      else
        logger&.warn "activerecord-import: the #{conn.adapter_name} adapter doesn't support bulk import, so #{model_name} " \
          "records are being inserted one at a time. If the adapter is supported under another name, require its " \
          "activerecord-import adapter, e.g. activerecord-import/active_record/adapters/postgresql_adapter."

        transaction(requires_new: true) do
          values_sql.each do |values|
            ids << conn.insert("#{insert_sql}#{values}#{comment_sql}", "#{model_name} Create Many")
            number_inserted += 1
          end
        end
      end
      ActiveRecord::Import::Result.new([], number_inserted, ids, results, affected_rows)
    end

    private

    # Takes the options Hash, if any, off the end of +args+ and returns the options
    # for the import, with their defaults, along with the arguments to import.
    def options_and_arguments_for_import(args)
      options = { validate: true, timestamps: true, track_validation_failures: false }
      options.merge!( args.pop ) if args.last.is_a? Hash
      args = arrays_from_array_like_import_arguments(args)
      # making sure that the current model and its primary key are used, rather than
      # the parent model's when importing associations recursively
      options[:model] = self
      options[:primary_key] = primary_key
      options[:locking_column] = locking_column if locking_enabled?
      [options, args]
    end

    # Returns the models to import from +args+, the column names to import them with,
    # and the columns the database populates for the models that don't assign them,
    # which is nil when +args+ give the column names.
    def models_and_column_names_for_import(conn, args)
      if args.length == 2
        models = args.last
        column_names = args.first.dup
      else
        models = args.first
        column_names = if conn.try(:supports_virtual_columns?)
          columns.reject(&:virtual?).map(&:name)
        else
          self.column_names.dup
        end
        populated_column_names = database_populated_column_names(conn, column_names, models)
        # Leave out the ones no model assigns, and let the database fill in the rest for the models that don't
        default_column_names = populated_column_names.select { |name| models.any? { |model| model.attribute_changed?(name) } }
        column_names -= populated_column_names - default_column_names
      end

      # Leave out a primary key the database populates, like a uuid, only when no model has one, so
      # assigned ids are kept. Otherwise the database fills it in for the models without one.
      column_names -= database_populated_primary_keys(conn) if models.all? { |model| model.id.nil? }

      [models, column_names, default_column_names]
    end

    # Returns the values of +column_names+ for each of +models+, the rows to import. Models
    # that +validator+ finds invalid are left out, or raise ActiveRecord::RecordInvalid with
    # the :raise_error option. Without a +validator+, the models aren't validated.
    def attributes_from_models(conn, models, column_names, validator, options)
      update_attrs = if record_timestamps && options[:timestamps]
        send(:timestamp_attributes_for_update).map(&:to_sym)
      end

      array_of_attributes = []

      models.each do |model|
        if supports_setting_primary_key_of_imported_objects?(conn)
          load_association_ids(model)
        end

        if validator && !validator.valid_model?(model)
          raise(ActiveRecord::RecordInvalid, model) if options[:raise_error]
          next
        end

        array_of_attributes << column_names.map do |name|
          if model.persisted? &&
             update_attrs && update_attrs.include?(name.to_sym) &&
             !model.send("#{name}_changed?")
            nil
          else
            name = name.to_s
            # Read a column's own value, as saving the model would, even if it's also an alias
            value = columns_hash.key?(name) ? model._read_attribute(name) : model.read_attribute(name)
            model.instance_of?(self) ? value : value_from_model_type(model, name, value)
          end
        end
      end

      array_of_attributes
    end

    # Returns the column names and the rows to import from +args+, which are either an
    # array of hashes, optionally after column names, or column names and an array of values.
    def column_names_and_attributes_for_import(args)
      # supports array of hash objects
      if args.last.is_a?( Array ) && args.last.first.is_a?(Hash)
        if args.length == 2
          array_of_hashes = args.last
          column_names = args.first.dup
          allow_extra_hash_keys = true
        else
          array_of_hashes = args.first
          column_names = array_of_hashes.first.keys
          allow_extra_hash_keys = false
        end

        array_of_attributes = array_of_hashes.map do |h|
          error_message = validate_hash_import(h, column_names, allow_extra_hash_keys)

          raise ArgumentError, error_message if error_message

          column_names.map do |key|
            h[key]
          end
        end
        # supports 2-element array and array
      elsif args.size == 2 && args.first.is_a?( Array ) && args.last.is_a?( Array )

        unless args.last.first.is_a?(Array)
          raise ArgumentError, "Last argument should be a two dimensional array '[[]]'. First element in array was a #{args.last.first.class}"
        end

        column_names, array_of_attributes = args

        # dup the passed args so we don't modify unintentionally
        column_names = column_names.dup
        array_of_attributes = array_of_attributes.map(&:dup)
      else
        raise ArgumentError, invalid_import_arguments_message(args)
      end

      [column_names, array_of_attributes]
    end

    # Returns a copy of the +on_duplicate_key_update+ option to import with, so it can be
    # changed, such as when adding timestamp columns, without modifying the option that was
    # passed in. :all is replaced by the columns other than the primary key and the
    # timestamps recorded on create.
    def on_duplicate_key_update_for_import(on_duplicate_key_update, column_names, options)
      symbolized_column_names = Array(column_names).map(&:to_sym)
      symbolized_primary_key = Array(primary_key).map(&:to_sym)

      updatable_columns = symbolized_column_names.reject { |c| symbolized_primary_key.include? c }
      # Like the primary key, timestamps recorded on create shouldn't change when a record is updated
      if record_timestamps && options[:timestamps]
        updatable_columns -= timestamp_attributes_for_create_in_model.map(&:to_sym)
      end

      if on_duplicate_key_update.is_a?(Hash)
        on_duplicate_key_update.each_with_object({}) do |(k, v), duped_options|
          duped_options[k] = if k == :columns && v == :all
            updatable_columns
          elsif v.duplicable?
            v.dup
          else
            v
          end
        end
      elsif on_duplicate_key_update == :all
        updatable_columns
      elsif on_duplicate_key_update.duplicable?
        on_duplicate_key_update.dup
      else
        on_duplicate_key_update
      end
    end

    # Force the primary key col into the insert if it's not
    # on the list and we are using a sequence and stuff a nil
    # value for it into each row so the sequencer will fire later
    def add_primary_key_for_sequence(conn, column_names, array_of_attributes)
      symbolized_column_names = Array(column_names).map(&:to_sym)
      symbolized_primary_key = Array(primary_key).map(&:to_sym)

      if !symbolized_primary_key.to_set.subset?(symbolized_column_names.to_set) && conn.prefetch_primary_key? && sequence_name
        column_count = column_names.size
        column_names.concat(Array(primary_key)).uniq!
        columns_added = column_names.size - column_count
        new_fields = Array.new(columns_added)
        array_of_attributes.each { |a| a.concat(new_fields) }
      end
    end

    # Adds the models that failed validation, when their rows were read, to +failed_instances+.
    def add_failed_models(failed_instances, models, options)
      models.each_with_index do |m, i|
        next unless m.errors.any?

        failed_instances << (options[:track_validation_failures] ? [i, m] : m)
      end
    end

    # Validates each row of +array_of_attributes+ as a new model, adding the models that
    # fail to +failed_instances+ and removing their rows from +array_of_attributes+.
    def validate_attributes_for_import(failed_instances, column_names, array_of_attributes, validator, options)
      # create instances for each of our column/value sets
      arr = validations_array_for_column_names_and_attributes( column_names, array_of_attributes )

      # keep track of the instance and the position it is currently at. if this fails
      # validation we'll use the index to remove it from the array_of_attributes
      arr.each_with_index do |hsh, i|
        # utilize block initializer syntax to prevent failure when 'mass_assignment_sanitizer = :strict'
        model = new do |m|
          hsh.each_pair do |k, v|
            if write_id_column_directly?(k)
              m._write_attribute("id", v)
            else
              m[k] = v
            end
          end
        end

        next if validator.valid_model?(model)
        raise(ActiveRecord::RecordInvalid, model) if options[:raise_error]

        array_of_attributes[i] = nil
        failure = model.dup
        failure.errors.send(:initialize_dup, model.errors)
        failed_instances << (options[:track_validation_failures] ? [i, failure] : failure )
      end
      array_of_attributes.compact!
    end

    # Imports the new and changed associations of the +models+ that were imported, with the
    # :on_duplicate_key_update option that was passed in rather than the copy used for +models+.
    def import_associations_of_imported_models(models, import_result, on_duplicate_key_update, options)
      options[:on_duplicate_key_update] = on_duplicate_key_update unless on_duplicate_key_update.nil?
      import_associations(imported_models(models, import_result, options), options.dup.merge(validate: false))
    end

    # ActiveRecord treats "id" as the primary key when writing attributes
    # through id= or []=. When the primary key is composite or is another
    # column, an "id" column has to be written directly instead.
    def write_id_column_directly?(column)
      column.to_s == "id" && primary_key != "id"
    end

    # Returns SQL comments for the annotations on the current scope, as
    # ActiveRecord adds them to its queries, or nil if there are none.
    def sql_comment_for_annotations(conn)
      annotations = all.annotate_values
      return if annotations.empty?

      " #{annotations.map { |value| "/* #{conn.sanitize_as_sql_comment(value)} */" }.join(' ')}"
    end

    def associated_options(options, association)
      return options unless options.key?(:recursive_on_duplicate_key_update)

      options.merge(
        on_duplicate_key_update: options[:recursive_on_duplicate_key_update][association]
      )
    end

    # Returns the models that weren't rejected by validations.
    def imported_models(models, import_result, options)
      failed_instances = import_result.failed_instances
      failed_instances = failed_instances.map(&:last) if options[:track_validation_failures]
      models - failed_instances
    end

    # Synchronizes +instances+ with the database like ActiveRecord::Base.synchronize,
    # but rather than discarding their changes, it assigns the database values
    # on top of them. Once the instances are marked clean, previous_changes then
    # reflects what the import changed, as it does without synchronizing.
    # Instances left without changes are marked clean right away. Returns the
    # instances that were synchronized.
    def synchronize_imported_instances(instances, keys)
      synchronize_instances(instances, keys) do |instance, fresh_attributes|
        attributes = instance.instance_variable_get(:@attributes)
        # the attributes of destroyed records are frozen
        attributes = attributes.deep_dup if attributes.frozen?

        names = fresh_attributes.keys
        if names.all? { |name| attributes.key?(name) }
          names.each do |name|
            value = fresh_attributes.fetch_value(name)
            attributes.write_from_user(name, value) unless same_database_value?(attributes.fetch_value(name), value)
          end
          instance.instance_variable_set :@attributes, attributes
          instance.changes_applied unless instance.changed?
        else
          # the instance doesn't have all of the attributes, such as when it was
          # loaded with select, so take the record's attributes as they are
          instance.instance_variable_set :@attributes, fresh_attributes
          instance.clear_changes_information
        end
      end
    end

    # Returns true if +database_value+, reloaded from the database, is the +value+ an instance
    # already has. Databases store times to the microsecond, so a time with more precision,
    # which ActiveRecord < 7.0 keeps in memory, comes back rounded or truncated.
    def same_database_value?(value, database_value)
      return true if value == database_value
      return false unless value.is_a?(Time) && database_value.is_a?(Time)

      value.round(6) == database_value || value.floor(6) == database_value
    end

    def set_attributes_and_mark_clean(conn, models, import_result, timestamps, options)
      return if models.nil?
      models = imported_models(models, import_result, options)

      # if ids were returned for all models we know all were updated
      if models.size == import_result.ids.size
        import_result.ids.each_with_index do |id, index|
          model = models[index]
          model.id = id

          timestamps.each do |attr, value|
            model.send("#{attr}=", value) if model.send(attr).nil?
          end
        end
      end

      deserialize_value = lambda do |column, value|
        column = schema_columns_hash(conn)[column]
        return value unless column
        type = type_for_attribute(column.name)
        type.deserialize(value)
      end

      set_value = lambda do |model, column, value|
        val = deserialize_value.call(column, value)
        if model.attribute_names.include?(column)
          if write_id_column_directly?(column)
            model._write_attribute(column, val)
          else
            model.send("#{column}=", val)
          end
        else
          attributes = attributes_builder.build_from_database(model.attributes.merge(column => val))
          model.instance_variable_set(:@attributes, attributes)
        end
      end

      columns = Array(options[:returning_columns])
      results = Array(import_result.results)
      if models.size == results.size
        single_column = columns.first if columns.size == 1
        results.each_with_index do |result, index|
          model = models[index]

          if single_column
            set_value.call(model, single_column, result)
          else
            columns.each_with_index do |column, col_index|
              set_value.call(model, column, result[col_index])
            end
          end
        end
      end

      models.each do |model|
        model.changes_applied
        model.instance_variable_set(:@new_record, false)
      end
    end

    # Sync belongs_to association ids with foreign key field
    def load_association_ids(model)
      changed_columns = model.changed
      association_reflections = model.class.reflect_on_all_associations(:belongs_to)
      association_reflections.each do |association_reflection|
        next if association_reflection.options[:polymorphic]

        column_names = Array(association_reflection.foreign_key).map(&:to_s)
        column_names.each_with_index do |column_name, column_index|
          next if changed_columns.include?(column_name)

          association = model.association(association_reflection.name)
          association = association.target
          next if association.blank? || model.public_send(column_name).present?

          association_primary_key = association_primary_key_names(association_reflection)[column_index]
          next unless association_primary_key

          model.public_send("#{column_name}=", association.send(association_primary_key))
        end
      end
    end

    # Returns the names of the columns that a belongs_to association's foreign key refers to.
    # For a composite key, ActiveRecord 7.1+ returns an Array, while older versions return
    # its string form, e.g. "[:account_id, :id]".
    def association_primary_key_names(association_reflection)
      association_primary_key = association_reflection.association_primary_key
      return association_primary_key.map(&:to_s) if association_primary_key.is_a?(Array)

      association_primary_key.tr("[]:", "").split(", ")
    end

    def import_associations(models, options)
      # now, for all the dirty associations, collect them into a new set of models, then recurse.
      # notes:
      #    does not handle associations that reference themselves
      #    should probably take a hash to associations to follow.
      return if models.nil?
      associated_objects_by_class = {}
      models.each { |model| find_associated_objects_for_import(associated_objects_by_class, model) }

      # :on_duplicate_key_update only supported for all fields
      options.delete(:on_duplicate_key_update) unless options[:on_duplicate_key_update] == :all
      # :returning not supported for associations
      options.delete(:returning)

      associated_objects_by_class.each_value do |associations|
        associations.each do |association, associated_records|
          next if associated_records.empty?

          associated_class = associated_records.first.class
          associated_class.bulk_import(associated_records,
                                       associated_options(options, association))
        end
      end
    end

    # Returns the columns the database populates itself, such as with a default
    # function, when importing new +models+. Like ActiveRecord's own inserts, the
    # database populates these for models that don't assign a value, instead of
    # inserting NULL. The primary key is handled separately.
    def database_populated_column_names(conn, column_names, models)
      return [] if models.any?(&:persisted?)

      columns_hash = schema_columns_hash(conn)
      primary_keys = Array(primary_key).map(&:to_s)

      column_names.select do |name|
        column = columns_hash[name.to_s]
        next false if column.nil? || primary_keys.include?(name.to_s)

        column.respond_to?(:auto_populated?) ? column.auto_populated? : column.default_function
      end
    end

    # Returns the primary key columns the database populates itself, such as a uuid
    # or a key with a default function, rather than from the model's sequence.
    def database_populated_primary_keys(conn)
      Array(primary_key).select do |name|
        column = schema_columns_hash(conn)[name]
        column && (column.type == :uuid || (column.default_function && sequence_name.blank?))
      end
    end

    # A model of another class, such as an STI subclass with its own enum, can give
    # a column a different type than this class, which serializes the imported values.
    # Convert the model's value to this class's type through its database value.
    def value_from_model_type(model, name, value)
      name = column_name_for_import(name)
      model_type = model.class.type_for_attribute(name)
      type = type_for_attribute(name)
      model_type.equal?(type) ? value : type.deserialize(model_type.serialize(value))
    end

    def schema_columns_hash(conn)
      if ignored_columns.any?
        conn.schema_cache.columns_hash(table_name)
      else
        columns_hash
      end
    end

    # We are eventually going to call Class.import <objects> so we build up a hash
    # of class => objects to import.
    def find_associated_objects_for_import(associated_objects_by_class, model)
      associated_objects_by_class[model.class.name] ||= {}
      return associated_objects_by_class unless model.id

      association_reflections =
        model.class.reflect_on_all_associations(:has_one) +
        model.class.reflect_on_all_associations(:has_many)
      association_reflections.each do |association_reflection|
        associated_objects_by_class[model.class.name][association_reflection.name] ||= []

        association = model.association(association_reflection.name)
        association.loaded!

        # Wrap target in an array if not already
        association = Array(association.target)

        foreign_key_columns = Array(association_reflection.inverse_of&.foreign_key || association_reflection.foreign_key)
        foreign_key_values = association_foreign_key_values(model, association_reflection)

        # For polymorphic associations
        association_name = model.class.polymorphic_name

        # Import new and changed records, and existing records that were assigned to
        # this model but aren't linked to it yet, as saving the model would
        changed_objects = association.select do |child|
          child.new_record? || child.changed? ||
            (!association_reflection.through_reflection? &&
              reassigned_to_parent?(child, foreign_key_columns, foreign_key_values, association_reflection.type, association_name))
        end

        changed_objects.each do |child|
          foreign_key_columns.each_with_index do |column, index|
            child.public_send("#{column}=", foreign_key_values[index])
          end

          association_reflection.type.try do |type|
            child.public_send("#{type}=", association_name)
          end
        end
        associated_objects_by_class[model.class.name][association_reflection.name].concat changed_objects
      end
      associated_objects_by_class
    end

    # Returns the values of +model+ that the foreign key of +association_reflection+
    # refers to: the columns named by the association's :primary_key option when
    # one is given (e.g. <tt>has_many :reviews, primary_key: :identifier</tt>),
    # and the model's id otherwise.
    def association_foreign_key_values(model, association_reflection)
      if association_reflection.options[:primary_key]
        Array(association_reflection.active_record_primary_key).map { |key| model.read_attribute(key) }
      else
        Array(model.id)
      end
    end

    # Returns true if +child+, an existing record of a has_one or has_many association,
    # doesn't refer to the parent yet, such as when it was assigned to a new parent.
    def reassigned_to_parent?(child, foreign_key_columns, foreign_key_values, type_column, type_name)
      return false if child.new_record?

      parent_values = foreign_key_columns.zip(foreign_key_values)
      parent_values << [type_column, type_name.to_s] if type_column.present?
      parent_values.any? { |column, value| child.has_attribute?(column) && child.read_attribute(column) != value }
    end

    # Returns SQL the VALUES for an INSERT statement given the passed in +columns+
    # and +array_of_attributes+. Nil values for +default_column_names+ use the
    # database's default.
    def values_sql_for_columns_and_attributes(conn, columns, array_of_attributes, default_column_names = []) # :nodoc:
      array_of_attributes.map do |arr|
        if arr.length < columns.length
          raise ArgumentError, "Number of values (#{arr.length}) is less than number of columns (#{columns.length})"
        end

        my_values = arr.each_with_index.map do |val, j|
          column = columns[j]

          # be sure to query sequence_name *last*, only if cheaper tests fail, because it's costly
          if val.nil? && Array(primary_key).first == column.name && !sequence_name.blank?
            conn.next_value_for_sequence(sequence_name)
          elsif val.nil? && default_column_names.include?(column.name)
            unless conn.supports_default_keyword_in_values?
              raise ArgumentError, "#{conn.adapter_name} doesn't support DEFAULT in VALUES, so the database can't populate " \
                "#{table_name}.#{column.name} for only the rows without a value. Import those rows separately so the column can be left out."
            end
            "DEFAULT"
          elsif val.respond_to?(:to_sql)
            "(#{val.to_sql})"
          elsif column
            type = type_for_attribute(column.name)
            val = !type.respond_to?(:subtype) && type.type == :boolean ? type.cast(val) : type.serialize(val)
            conn.quote(val)
          else
            raise ArgumentError, "Number of values (#{arr.length}) exceeds number of columns (#{columns.length})"
          end
        end
        "(#{my_values.join(',')})"
      end
    end

    def add_special_rails_stamps( conn, column_names, array_of_attributes, options )
      timestamp_columns = {}
      timestamps        = {}

      timestamp_columns[:create] = timestamp_attributes_for_create_in_model
      timestamp_columns[:update] = timestamp_attributes_for_update_in_model

      # use tz as set in ActiveRecord::Base
      default_timezone = if ActiveRecord.respond_to?(:default_timezone)
        ActiveRecord.default_timezone
      else
        ActiveRecord::Base.default_timezone
      end
      timestamp = default_timezone == :utc ? Time.now.utc : Time.now

      [:create, :update].each do |action|
        timestamp_columns[action].each do |column|
          column = column.to_s
          timestamps[column] = timestamp

          index = column_names.index(column) || column_names.index(column.to_sym)
          if index
            # replace every instance of the array of attributes with our value
            array_of_attributes.each { |arr| arr[index] = timestamp if arr[index].nil? }
          else
            column_names << column
            array_of_attributes.each { |arr| arr << timestamp }
          end

          if supports_on_duplicate_key_update?(conn) && action == :update
            conn.add_column_for_on_duplicate_key_update(column, options)
          end
        end
      end

      timestamps
    end

    # Converts array-like arguments, such as a Relation or a Set, to arrays.
    def arrays_from_array_like_import_arguments(args) # :nodoc:
      args.map { |arg| arg.is_a?(Enumerable) && !arg.is_a?(Array) && !arg.is_a?(Hash) ? arg.to_a : arg }
    end

    def invalid_import_arguments_message(args) # :nodoc:
      received = args.map { |arg| arg.is_a?(Array) && arg.any? ? "Array of #{arg.first.class}" : arg.class.name }
      "Invalid arguments! Expected an array of models, an array of hashes, or column names and an array " \
        "of values, but received #{received.empty? ? 'no arguments' : received.join(', ')}"
    end

    # Returns an Array of Hashes for the passed in +column_names+ and +array_of_attributes+.
    def validations_array_for_column_names_and_attributes( column_names, array_of_attributes ) # :nodoc:
      array_of_attributes.map { |values| Hash[column_names.zip(values)] }
    end

    # Checks that the imported hash has the required_keys, optionally also checks that the hash has
    # no keys beyond those required when `allow_extra_keys` is false.
    # returns `nil` if validation passes, or an error message if it fails
    def validate_hash_import(hash, required_keys, allow_extra_keys) # :nodoc:
      extra_keys = allow_extra_keys ? [] : hash.keys - required_keys
      missing_keys = required_keys - hash.keys

      return nil if extra_keys.empty? && missing_keys.empty?

      if allow_extra_keys
        <<-EOS
Hash key mismatch.

When importing an array of hashes with provided columns_names, each hash must contain keys for all column_names.

Required keys: #{required_keys}
Missing keys: #{missing_keys}
        EOS
      else
        <<-EOS
Hash key mismatch.

When importing an array of hashes, all hashes must have the same keys.
If you have records that are missing some values, we recommend you either set default values
for the missing keys or group these records into batches by key set before importing.

Required keys: #{required_keys}
Extra keys: #{extra_keys}
Missing keys: #{missing_keys}
        EOS
      end
    end
  end
end
