require "ostruct"

module ActiveRecord::Import::ConnectionAdapters; end

module ActiveRecord::Import #:nodoc:
  Result = Struct.new(:failed_instances, :num_inserts, :ids)

  module ImportSupport #:nodoc:
    def supports_import? #:nodoc:
      true
    end
  end

  module OnDuplicateKeyUpdateSupport #:nodoc:
    def supports_on_duplicate_key_update? #:nodoc:
      true
    end
  end

  class MissingColumnError < StandardError
    def initialize(name, index)
      super "Missing column for value <#{name}> at index #{index}"
    end
  end
end

class ActiveRecord::Associations::CollectionProxy
  def import(*args, &block)
    @association.import(*args, &block)
  end
end

class ActiveRecord::Associations::CollectionAssociation
  def import(*args, &block)
    unless owner.persisted?
      raise ActiveRecord::RecordNotSaved, "You cannot call import unless the parent is saved"
    end

    options = args.last.is_a?(Hash) ? args.pop : {}

    model_klass = reflection.klass
    symbolized_foreign_key = reflection.foreign_key.to_sym
    symbolized_column_names = model_klass.column_names.map(&:to_sym)

    owner_primary_key = owner.class.primary_key
    owner_primary_key_value = owner.send(owner_primary_key)

    # assume array of model objects
    if args.last.is_a?( Array ) && args.last.first.is_a?(ActiveRecord::Base)
      if args.length == 2
        models = args.last
        column_names = args.first
      else
        models = args.first
        column_names = symbolized_column_names
      end

      unless symbolized_column_names.include?(symbolized_foreign_key)
        column_names << symbolized_foreign_key
      end

      models.each do |m|
        m.public_send "#{symbolized_foreign_key}=", owner_primary_key_value
        m.public_send "#{reflection.type}=", owner.class.name if reflection.type
      end

      return model_klass.import column_names, models, options

    # supports empty array
    elsif args.last.is_a?( Array ) && args.last.empty?
      return ActiveRecord::Import::Result.new([], 0, [])

    # supports 2-element array and array
    elsif args.size == 2 && args.first.is_a?( Array ) && args.last.is_a?( Array )
      column_names, array_of_attributes = args
      symbolized_column_names = column_names.map(&:to_s)

      if symbolized_column_names.include?(symbolized_foreign_key)
        index = symbolized_column_names.index(symbolized_foreign_key)
        array_of_attributes.each { |attrs| attrs[index] = owner_primary_key_value }
      else
        column_names << symbolized_foreign_key
        array_of_attributes.each { |attrs| attrs << owner_primary_key_value }
      end

      if reflection.type
        column_names << reflection.type
        array_of_attributes.each { |attrs| attrs << owner.class.name }
      end

      return model_klass.import column_names, array_of_attributes, options
    else
      raise ArgumentError, "Invalid arguments!"
    end
  end
end

class ActiveRecord::Base
  class << self
    # use tz as set in ActiveRecord::Base
    tproc = lambda do
      ActiveRecord::Base.default_timezone == :utc ? Time.now.utc : Time.now
    end

    AREXT_RAILS_COLUMNS = {
      create: { "created_on" => tproc,
                "created_at" => tproc },
      update: { "updated_on" => tproc,
                "updated_at" => tproc }
    }.freeze
    AREXT_RAILS_COLUMN_NAMES = AREXT_RAILS_COLUMNS[:create].keys + AREXT_RAILS_COLUMNS[:update].keys

    # Returns true if the current database connection adapter
    # supports import functionality, otherwise returns false.
    def supports_import?(*args)
      connection.respond_to?(:supports_import?) && connection.supports_import?(*args)
    end

    # Returns true if the current database connection adapter
    # supports on duplicate key update functionality, otherwise
    # returns false.
    def supports_on_duplicate_key_update?
      connection.supports_on_duplicate_key_update?
    end

    # returns true if the current database connection adapter
    # supports setting the primary key of bulk imported models, otherwise
    # returns false
    def support_setting_primary_key_of_imported_objects?
      connection.respond_to?(:support_setting_primary_key_of_imported_objects?) && connection.support_setting_primary_key_of_imported_objects?
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
    #    ActiveRecord validations. Validations are enforced by default.
    # * +ignore+ - true|false, an alias for on_duplicate_key_ignore.
    # * +on_duplicate_key_ignore+ - true|false, tells import to discard
    #    records that contain duplicate keys. For Postgres 9.5+ it adds
    #    ON CONFLICT DO NOTHING, for MySQL it uses INSERT IGNORE, and for
    #    SQLite it uses INSERT OR IGNORE. Cannot be enabled on a
    #    recursive import.
    # * +on_duplicate_key_update+ - an Array or Hash, tells import to
    #    use MySQL's ON DUPLICATE KEY UPDATE or Postgres 9.5+ ON CONFLICT
    #    DO UPDATE ability. See On Duplicate Key Update below.
    # * +synchronize+ - an array of ActiveRecord instances for the model
    #   that you are currently importing data into. This synchronizes
    #   existing model instances in memory with updates from the import.
    # * +timestamps+ - true|false, tells import to not add timestamps
    #   (if false) even if record timestamps is disabled in ActiveRecord::Base
    # * +recursive+ - true|false, tells import to import all has_many/has_one
    #   associations if the adapter supports setting the primary keys of the
    #   newly imported objects. PostgreSQL only.
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
    # The :on_duplicate_key_update option can be either an Array or a Hash.
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
    # == On Duplicate Key Update (Postgres 9.5+)
    #
    # The :on_duplicate_key_update option can be an Array or a Hash with up to
    # three attributes, :conflict_target (and optionally :index_predicate) or
    # :constraint_name, and :columns.
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
    # ====== :conflict_target
    #
    # The :conflict_target attribute specifies the columns that make up the
    # conflicting unique constraint and can be a single column or an array of
    # column names. This attribute is ignored if :constraint_name is included,
    # but it is the preferred method of identifying a constraint. It will
    # default to the primary key. Below is an example:
    #
    #   BlogPost.import columns, values, on_duplicate_key_update: { conflict_target: [ :author_id, :slug ], columns: [ :date_modified ] }
    #
    # ====== :index_predicate
    #
    # The :index_predicate attribute optionally specifies a WHERE condition
    # on :conflict_target, which is required for matching against partial
    # indexes. This attribute is ignored if :constraint_name is included.
    # Below is an example:
    #
    #   BlogPost.import columns, values, on_duplicate_key_update: { conflict_target: [ :author_id, :slug ], index_predicate: 'status <> 0', columns: [ :date_modified ] }
    #
    # ====== :constraint_name
    #
    # The :constraint_name attribute explicitly identifies the conflicting
    # unique index by name. Postgres documentation discourages using this method
    # of identifying an index unless absolutely necessary. Below is an example:
    #
    #   BlogPost.import columns, values, on_duplicate_key_update: { constraint_name: :blog_posts_pkey, columns: [ :date_modified ] }
    #
    # ====== :columns
    #
    # The :columns attribute can be either an Array or a Hash.
    #
    # ======== Using an Array
    #
    # The :columns attribute can be an array of column names. The column names
    # are the only fields that are updated if a duplicate record is found.
    # Below is an example:
    #
    #   BlogPost.import columns, values, on_duplicate_key_update: { conflict_target: :slug, columns: [ :date_modified, :content, :author ] }
    #
    # ========  Using a Hash
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
    def import(*args)
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
    def import!(*args)
      options = args.last.is_a?( Hash ) ? args.pop : {}
      options[:validate] = true
      options[:raise_error] = true

      import(*args, options)
    end

    def import_helper( *args )
      options = { validate: true, timestamps: true }
      options.merge!( args.pop ) if args.last.is_a? Hash
      # making sure that current model's primary key is used
      options[:primary_key] = primary_key

      # Don't modify incoming arguments
      if options[:on_duplicate_key_update] && options[:on_duplicate_key_update].duplicable?
        options[:on_duplicate_key_update] = options[:on_duplicate_key_update].dup
      end

      is_validating = options[:validate]
      is_validating = true unless options[:validate_with_context].nil?

      # assume array of model objects
      if args.last.is_a?( Array ) && args.last.first.is_a?(ActiveRecord::Base)
        if args.length == 2
          models = args.last
          column_names = args.first.dup
        else
          models = args.first
          column_names = self.column_names.dup
        end

        if models.first.id.nil? && column_names.include?(primary_key) && columns_hash[primary_key].type == :uuid
          column_names.delete(primary_key)
        end

        stored_attrs = respond_to?(:stored_attributes) ? stored_attributes : {}

        array_of_attributes = models.map do |model|
          column_names.map do |name|
            if stored_attrs.any? && stored_attrs.key?(name.to_sym)
              model.read_attribute(name.to_s)
            else
              model.read_attribute_before_type_cast(name.to_s)
            end
          end
        end
        # supports array of hash objects
      elsif args.last.is_a?( Array ) && args.last.first.is_a?(Hash)
        if args.length == 2
          array_of_hashes = args.last
          column_names = args.first.dup
        else
          array_of_hashes = args.first
          column_names = array_of_hashes.first.keys
        end

        array_of_attributes = array_of_hashes.map do |h|
          column_names.map do |key|
            h[key]
          end
        end
        # supports empty array
      elsif args.last.is_a?( Array ) && args.last.empty?
        return ActiveRecord::Import::Result.new([], 0, [])
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
        raise ArgumentError, "Invalid arguments!"
      end

      # Force the primary key col into the insert if it's not
      # on the list and we are using a sequence and stuff a nil
      # value for it into each row so the sequencer will fire later
      symbolized_column_names = Array(column_names).map(&:to_sym)
      symbolized_primary_key = Array(primary_key).map(&:to_sym)

      if !symbolized_primary_key.to_set.subset?(symbolized_column_names.to_set) && connection.prefetch_primary_key? && sequence_name
        column_count = column_names.size
        column_names.concat(primary_key).uniq!
        columns_added = column_names.size - column_count
        new_fields = Array.new(columns_added)
        array_of_attributes.each { |a| a.concat(new_fields) }
      end

      timestamps = {}

      # record timestamps unless disabled in ActiveRecord::Base
      if record_timestamps && options.delete( :timestamps )
        timestamps = add_special_rails_stamps column_names, array_of_attributes, options
      end

      return_obj = if is_validating
        if models
          import_with_validations( column_names, array_of_attributes, options ) do |failed|
            models.each_with_index do |model, i|
              model = model.dup if options[:recursive]
              next if model.valid?(options[:validate_with_context])
              raise(ActiveRecord::RecordInvalid, model) if options[:raise_error]
              array_of_attributes[i] = nil
              failed << model
            end
          end
        else
          import_with_validations( column_names, array_of_attributes, options )
        end
      else
        (num_inserts, ids) = import_without_validations_or_callbacks( column_names, array_of_attributes, options )
        ActiveRecord::Import::Result.new([], num_inserts, ids)
      end

      if options[:synchronize]
        sync_keys = options[:synchronize_keys] || [primary_key]
        synchronize( options[:synchronize], sync_keys)
      end
      return_obj.num_inserts = 0 if return_obj.num_inserts.nil?

      # if we have ids, then set the id on the models and mark the models as clean.
      if models && support_setting_primary_key_of_imported_objects?
        set_attributes_and_mark_clean(models, return_obj, timestamps)

        # if there are auto-save associations on the models we imported that are new, import them as well
        import_associations(models, options.dup) if options[:recursive]
      end

      return_obj
    end

    # TODO import_from_table needs to be implemented.
    def import_from_table( options ) # :nodoc:
    end

    # Imports the passed in +column_names+ and +array_of_attributes+
    # given the passed in +options+ Hash with validations. Returns an
    # object with the methods +failed_instances+ and +num_inserts+.
    # +failed_instances+ is an array of instances that failed validations.
    # +num_inserts+ is the number of inserts it took to import the data. See
    # ActiveRecord::Base.import for more information on
    # +column_names+, +array_of_attributes+ and +options+.
    def import_with_validations( column_names, array_of_attributes, options = {} )
      failed_instances = []

      if block_given?
        yield failed_instances
      else
        # create instances for each of our column/value sets
        arr = validations_array_for_column_names_and_attributes( column_names, array_of_attributes )

        # keep track of the instance and the position it is currently at. if this fails
        # validation we'll use the index to remove it from the array_of_attributes
        model = new
        arr.each_with_index do |hsh, i|
          hsh.each_pair { |k, v| model[k] = v }
          next if model.valid?(options[:validate_with_context])
          raise(ActiveRecord::RecordInvalid, model) if options[:raise_error]
          array_of_attributes[i] = nil
          failure = model.dup
          failure.errors.send(:initialize_dup, model.errors)
          failed_instances << failure
        end
      end

      array_of_attributes.compact!

      num_inserts, ids = if array_of_attributes.empty? || options[:all_or_none] && failed_instances.any?
        [0, []]
      else
        import_without_validations_or_callbacks( column_names, array_of_attributes, options )
      end
      ActiveRecord::Import::Result.new(failed_instances, num_inserts, ids)
    end

    # Imports the passed in +column_names+ and +array_of_attributes+
    # given the passed in +options+ Hash. This will return the number
    # of insert operations it took to create these records without
    # validations or callbacks. See ActiveRecord::Base.import for more
    # information on +column_names+, +array_of_attributes_ and
    # +options+.
    def import_without_validations_or_callbacks( column_names, array_of_attributes, options = {} )
      column_names = column_names.map(&:to_sym)
      scope_columns, scope_values = scope_attributes.to_a.transpose

      unless scope_columns.blank?
        scope_columns.zip(scope_values).each do |name, value|
          name_as_sym = name.to_sym
          next if column_names.include?(name_as_sym)

          is_sti = (name_as_sym == inheritance_column.to_sym && self < base_class)
          value = value.first if is_sti

          column_names << name_as_sym
          array_of_attributes.each { |attrs| attrs << value }
        end
      end

      columns = column_names.each_with_index.map do |name, i|
        column = columns_hash[name.to_s]

        raise ActiveRecord::Import::MissingColumnError.new(name.to_s, i) if column.nil?

        column
      end

      columns_sql = "(#{column_names.map { |name| connection.quote_column_name(name) }.join(',')})"
      pre_sql_statements = connection.pre_sql_statements( options )
      insert_sql = ['INSERT', pre_sql_statements, "INTO #{quoted_table_name} #{columns_sql} VALUES "]
      insert_sql = insert_sql.flatten.join(' ')
      values_sql = values_sql_for_columns_and_attributes(columns, array_of_attributes)

      number_inserted = 0
      ids = []
      if supports_import?
        # generate the sql
        post_sql_statements = connection.post_sql_statements( quoted_table_name, options )

        batch_size = options[:batch_size] || values_sql.size
        values_sql.each_slice(batch_size) do |batch_values|
          # perform the inserts
          result = connection.insert_many( [insert_sql, post_sql_statements].flatten,
            batch_values,
            options,
            "#{self.class.name} Create Many Without Validations Or Callbacks" )
          number_inserted += result[0]
          ids += result[1]
        end
      else
        transaction(requires_new: true) do
          values_sql.each do |values|
            ids << connection.insert(insert_sql + values)
            number_inserted += 1
          end
        end
      end
      [number_inserted, ids]
    end

    private

    def set_attributes_and_mark_clean(models, import_result, timestamps)
      return if models.nil?
      models -= import_result.failed_instances
      import_result.ids.each_with_index do |id, index|
        model = models[index]
        model.id = id
        if model.respond_to?(:clear_changes_information) # Rails 4.0 and higher
          model.clear_changes_information
        else # Rails 3.2
          model.instance_variable_get(:@changed_attributes).clear
        end
        model.instance_variable_set(:@new_record, false)

        timestamps.each do |attr, value|
          model.send(attr + "=", value)
        end
      end
    end

    def import_associations(models, options)
      # now, for all the dirty associations, collect them into a new set of models, then recurse.
      # notes:
      #    does not handle associations that reference themselves
      #    should probably take a hash to associations to follow.
      return if models.nil?
      associated_objects_by_class = {}
      models.each { |model| find_associated_objects_for_import(associated_objects_by_class, model) }

      # :on_duplicate_key_update not supported for associations
      options.delete(:on_duplicate_key_update)

      associated_objects_by_class.each_value do |associations|
        associations.each_value do |associated_records|
          associated_records.first.class.import(associated_records, options) unless associated_records.empty?
        end
      end
    end

    # We are eventually going to call Class.import <objects> so we build up a hash
    # of class => objects to import.
    def find_associated_objects_for_import(associated_objects_by_class, model)
      associated_objects_by_class[model.class.name] ||= {}

      association_reflections =
        model.class.reflect_on_all_associations(:has_one) +
        model.class.reflect_on_all_associations(:has_many)
      association_reflections.each do |association_reflection|
        associated_objects_by_class[model.class.name][association_reflection.name] ||= []

        association = model.association(association_reflection.name)
        association.loaded!

        # Wrap target in an array if not already
        association = Array(association.target)

        changed_objects = association.select { |a| a.new_record? || a.changed? }
        changed_objects.each do |child|
          child.public_send("#{association_reflection.foreign_key}=", model.id)
          # For polymorphic associations
          association_reflection.type.try do |type|
            child.public_send("#{type}=", model.class.base_class.name)
          end
        end
        associated_objects_by_class[model.class.name][association_reflection.name].concat changed_objects
      end
      associated_objects_by_class
    end

    # Returns SQL the VALUES for an INSERT statement given the passed in +columns+
    # and +array_of_attributes+.
    def values_sql_for_columns_and_attributes(columns, array_of_attributes) # :nodoc:
      # connection and type_caster get called a *lot* in this high intensity loop.
      # Reuse the same ones w/in the loop, otherwise they would keep being re-retreived (= lots of time for large imports)
      connection_memo = connection
      type_caster_memo = type_caster if respond_to?(:type_caster)

      array_of_attributes.map do |arr|
        my_values = arr.each_with_index.map do |val, j|
          column = columns[j]

          # be sure to query sequence_name *last*, only if cheaper tests fail, because it's costly
          if val.nil? && column.name == primary_key && !sequence_name.blank?
            connection_memo.next_value_for_sequence(sequence_name)
          elsif column
            if defined?(type_caster_memo) && type_caster_memo.respond_to?(:type_cast_for_database) # Rails 5.0 and higher
              connection_memo.quote(type_caster_memo.type_cast_for_database(column.name, val))
            elsif column.respond_to?(:type_cast_from_user)                                   # Rails 4.2 and higher
              connection_memo.quote(column.type_cast_from_user(val), column)
            else                                                                             # Rails 3.2, 4.0 and 4.1
              if serialized_attributes.include?(column.name)
                val = serialized_attributes[column.name].dump(val)
              end
              connection_memo.quote(column.type_cast(val), column)
            end
          end
        end
        "(#{my_values.join(',')})"
      end
    end

    def add_special_rails_stamps( column_names, array_of_attributes, options )
      timestamps = {}

      AREXT_RAILS_COLUMNS[:create].each_pair do |key, blk|
        next unless self.column_names.include?(key)
        value = blk.call
        timestamps[key] = value

        index = column_names.index(key) || column_names.index(key.to_sym)
        if index
          # replace every instance of the array of attributes with our value
          array_of_attributes.each { |arr| arr[index] = value if arr[index].nil? }
        else
          column_names << key
          array_of_attributes.each { |arr| arr << value }
        end
      end

      AREXT_RAILS_COLUMNS[:update].each_pair do |key, blk|
        next unless self.column_names.include?(key)
        value = blk.call
        timestamps[key] = value

        index = column_names.index(key) || column_names.index(key.to_sym)
        if index
          # replace every instance of the array of attributes with our value
          array_of_attributes.each { |arr| arr[index] = value }
        else
          column_names << key
          array_of_attributes.each { |arr| arr << value }
        end

        if supports_on_duplicate_key_update?
          connection.add_column_for_on_duplicate_key_update(key, options)
        end
      end

      timestamps
    end

    # Returns an Array of Hashes for the passed in +column_names+ and +array_of_attributes+.
    def validations_array_for_column_names_and_attributes( column_names, array_of_attributes ) # :nodoc:
      array_of_attributes.map { |values| Hash[column_names.zip(values)] }
    end
  end
end
