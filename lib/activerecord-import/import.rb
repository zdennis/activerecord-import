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
      end

      return model_klass.import column_names, models, options

    # supports empty array
    elsif args.last.is_a?( Array ) && args.last.empty?
      return ActiveRecord::Import::Result.new([], 0, []) if args.last.empty?

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
    # * +ignore+ - true|false, tells import to use MySQL's INSERT IGNORE
    #    to discard records that contain duplicate keys.
    # * +on_duplicate_key_ignore+ - true|false, tells import to use
    #    Postgres 9.5+ ON CONFLICT DO NOTHING.
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
    #   newly imported objects.
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
    # two attributes, :conflict_target or :constraint_name and :columns.
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
    # The :on_duplicate_update option can be a hash with up to two attributes,
    # :conflict_target or constraint_name, and :columns. Unlike MySQL, Postgres
    # requires the conflicting constraint to be explicitly specified. Using this
    # option allows you to specify a constraint other than the primary key.
    #
    # ====== :conflict_target
    #
    # The :conflict_target attribute specifies the columns that make up the
    # conflicting unique constraint and can be a single column or an array of
    # column names. This attribute is ignored if :constraint_name is included,
    # but it is the preferred method of identifying a constraint. It will
    # default to the primary key. Below is an example:
    #
    #   BlogPost.import columns, values, on_duplicate_key_update: { conflict_target: [:author_id, :slug], columns: [ :date_modified ] }
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
    # * ids - the primary keys of the imported ids, if the adpater supports it, otherwise and empty array.
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
      options = { validate: true, timestamps: true, primary_key: primary_key }
      options.merge!( args.pop ) if args.last.is_a? Hash

      # Don't modify incoming arguments
      if options[:on_duplicate_key_update]
        options[:on_duplicate_key_update] = options[:on_duplicate_key_update].dup
      end

      is_validating = options[:validate]
      is_validating = true unless options[:validate_with_context].nil?

      # assume array of model objects
      if args.last.is_a?( Array ) && args.last.first.is_a?(ActiveRecord::Base)
        if args.length == 2
          models = args.last
          column_names = args.first
        else
          models = args.first
          column_names = self.column_names.dup
        end

        array_of_attributes = models.map do |model|
          # this next line breaks sqlite.so with a segmentation fault
          # if model.new_record? || options[:on_duplicate_key_update]
          column_names.map do |name|
            name = name.to_s
            if respond_to?(:defined_enums) && defined_enums.key?(name) # ActiveRecord 5
              model.read_attribute(name)
            else
              model.read_attribute_before_type_cast(name)
            end
          end
          # end
        end
        # supports empty array
      elsif args.last.is_a?( Array ) && args.last.empty?
        return ActiveRecord::Import::Result.new([], 0, []) if args.last.empty?
        # supports 2-element array and array
      elsif args.size == 2 && args.first.is_a?( Array ) && args.last.is_a?( Array )
        column_names, array_of_attributes = args
      else
        raise ArgumentError, "Invalid arguments!"
      end

      # dup the passed in array so we don't modify it unintentionally
      column_names = column_names.dup
      array_of_attributes = array_of_attributes.dup

      # Force the primary key col into the insert if it's not
      # on the list and we are using a sequence and stuff a nil
      # value for it into each row so the sequencer will fire later
      if !column_names.include?(primary_key) && connection.prefetch_primary_key? && sequence_name
        column_names << primary_key
        array_of_attributes.each { |a| a << nil }
      end

      # record timestamps unless disabled in ActiveRecord::Base
      if record_timestamps && options.delete( :timestamps )
        add_special_rails_stamps column_names, array_of_attributes, options
      end

      return_obj = if is_validating
        import_with_validations( column_names, array_of_attributes, options )
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
      if support_setting_primary_key_of_imported_objects?
        set_ids_and_mark_clean(models, return_obj)

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

      # create instances for each of our column/value sets
      arr = validations_array_for_column_names_and_attributes( column_names, array_of_attributes )

      # keep track of the instance and the position it is currently at. if this fails
      # validation we'll use the index to remove it from the array_of_attributes
      arr.each_with_index do |hsh, i|
        instance = new do |model|
          hsh.each_pair { |k, v| model[k] = v }
        end

        next if instance.valid?(options[:validate_with_context])
        raise(ActiveRecord::RecordInvalid, instance) if options[:raise_error]
        array_of_attributes[i] = nil
        failed_instances << instance
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
      insert_sql = "INSERT #{options[:ignore] ? 'IGNORE ' : ''}INTO #{quoted_table_name} #{columns_sql} VALUES "
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
            "#{self.class.name} Create Many Without Validations Or Callbacks" )
          number_inserted += result[0]
          ids += result[1]
        end
      else
        values_sql.each do |values|
          connection.execute(insert_sql + values)
          number_inserted += 1
        end
      end
      [number_inserted, ids]
    end

    private

    def set_ids_and_mark_clean(models, import_result)
      return if models.nil?
      import_result.ids.each_with_index do |id, index|
        model = models[index]
        model.id = id.to_i
        if model.respond_to?(:clear_changes_information) # Rails 4.0 and higher
          model.clear_changes_information
        else # Rails 3.1
          model.instance_variable_get(:@changed_attributes).clear
        end
        model.instance_variable_set(:@new_record, false)
      end
    end

    def import_associations(models, options)
      # now, for all the dirty associations, collect them into a new set of models, then recurse.
      # notes:
      #    does not handle associations that reference themselves
      #    should probably take a hash to associations to follow.
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
            child.public_send("#{type}=", model.class.name)
          end
        end
        associated_objects_by_class[model.class.name][association_reflection.name].concat changed_objects
      end
      associated_objects_by_class
    end

    # Returns SQL the VALUES for an INSERT statement given the passed in +columns+
    # and +array_of_attributes+.
    def values_sql_for_columns_and_attributes(columns, array_of_attributes) # :nodoc:
      # connection gets called a *lot* in this high intensity loop.
      # Reuse the same one w/in the loop, otherwise it would keep being re-retreived (= lots of time for large imports)
      connection_memo = connection
      array_of_attributes.map do |arr|
        my_values = arr.each_with_index.map do |val, j|
          column = columns[j]

          # be sure to query sequence_name *last*, only if cheaper tests fail, because it's costly
          if val.nil? && column.name == primary_key && !sequence_name.blank?
            connection_memo.next_value_for_sequence(sequence_name)
          elsif column
            if respond_to?(:type_caster) && type_caster.respond_to?(:type_cast_for_database) # Rails 5.0 and higher
              connection_memo.quote(type_caster.type_cast_for_database(column.name, val))
            elsif column.respond_to?(:type_cast_from_user)                                   # Rails 4.2 and higher
              connection_memo.quote(column.type_cast_from_user(val), column)
            else                                                                             # Rails 3.1, 3.2, 4.0 and 4.1
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
      AREXT_RAILS_COLUMNS[:create].each_pair do |key, blk|
        next unless self.column_names.include?(key)
        value = blk.call
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
    end

    # Returns an Array of Hashes for the passed in +column_names+ and +array_of_attributes+.
    def validations_array_for_column_names_and_attributes( column_names, array_of_attributes ) # :nodoc:
      array_of_attributes.map do |attributes|
        Hash[attributes.each_with_index.map { |attr, c| [column_names[c], attr] }]
      end
    end
  end
end
