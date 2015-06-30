require "ostruct"

module ActiveRecord::Import::ConnectionAdapters ; end

module ActiveRecord::Import #:nodoc:
  class Result < Struct.new(:failed_instances, :num_inserts, :ids)
  end

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

    model_klass = self.reflection.klass
    symbolized_foreign_key = self.reflection.foreign_key.to_sym
    symbolized_column_names = model_klass.column_names.map(&:to_sym)

    owner_primary_key = self.owner.class.primary_key
    owner_primary_key_value = self.owner.send(owner_primary_key)

    # assume array of model objects
    if args.last.is_a?( Array ) and args.last.first.is_a? ActiveRecord::Base
      if args.length == 2
        models = args.last
        column_names = args.first
      else
        models = args.first
        column_names = symbolized_column_names
      end

      if !symbolized_column_names.include?(symbolized_foreign_key)
        column_names << symbolized_foreign_key
      end

      models.each do |m|
        m.send "#{symbolized_foreign_key}=", owner_primary_key_value
      end

      return model_klass.import column_names, models, options

    # supports empty array
    elsif args.last.is_a?( Array ) and args.last.empty?
      return ActiveRecord::Import::Result.new([], 0, []) if args.last.empty?

    # supports 2-element array and array
    elsif args.size == 2 and args.first.is_a?( Array ) and args.last.is_a?( Array )
      column_names, array_of_attributes = args
      symbolized_column_names = column_names.map(&:to_s)

      if !symbolized_column_names.include?(symbolized_foreign_key)
        column_names << symbolized_foreign_key
        array_of_attributes.each { |attrs| attrs << owner_primary_key_value }
      else
        index = symbolized_column_names.index(symbolized_foreign_key)
        array_of_attributes.each { |attrs| attrs[index] = owner_primary_key_value }
      end

      return model_klass.import column_names, array_of_attributes, options
    else
      raise ArgumentError.new( "Invalid arguments!" )
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
      :create => { "created_on" => tproc ,
                   "created_at" => tproc },
      :update => { "updated_on" => tproc ,
                   "updated_at" => tproc }
    }
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
      connection.respond_to?(:supports_on_duplicate_key_update?) && connection.supports_on_duplicate_key_update?
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
    # * +validate+ - true|false, tells import whether or not to use \
    #    ActiveRecord validations. Validations are enforced by default.
    # * +on_duplicate_key_update+ - an Array or Hash, tells import to \
    #    use MySQL's ON DUPLICATE KEY UPDATE ability. See On Duplicate\
    #    Key Update below.
    # * +synchronize+ - an array of ActiveRecord instances for the model
    #   that you are currently importing data into. This synchronizes
    #   existing model instances in memory with updates from the import.
    # * +timestamps+ - true|false, tells import to not add timestamps \
    #   (if false) even if record timestamps is disabled in ActiveRecord::Base
    # * +recursive - true|false, tells import to import all autosave association
    #   if the adapter supports setting the primary keys of the newly imported
    #   objects.
    #
    # == Examples
    #  class BlogPost < ActiveRecord::Base ; end
    #
    #  # Example using array of model objects
    #  posts = [ BlogPost.new :author_name=>'Zach Dennis', :title=>'AREXT',
    #            BlogPost.new :author_name=>'Zach Dennis', :title=>'AREXT2',
    #            BlogPost.new :author_name=>'Zach Dennis', :title=>'AREXT3' ]
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
    #  BlogPost.import( columns, values, :validate => false  )
    #
    #  # Example synchronizing existing instances in memory
    #  post = BlogPost.where(author_name: 'zdennis').first
    #  puts post.author_name # => 'zdennis'
    #  columns = [ :author_name, :title ]
    #  values = [ [ 'yoda', 'test post' ] ]
    #  BlogPost.import posts, :synchronize=>[ post ]
    #  puts post.author_name # => 'yoda'
    #
    #  # Example synchronizing unsaved/new instances in memory by using a uniqued imported field
    #  posts = [BlogPost.new(:title => "Foo"), BlogPost.new(:title => "Bar")]
    #  BlogPost.import posts, :synchronize => posts, :synchronize_keys => [:title]
    #  puts posts.first.persisted? # => true
    #
    # == On Duplicate Key Update (MySQL only)
    #
    # The :on_duplicate_key_update option can be either an Array or a Hash.
    #
    # ==== Using an Array
    #
    # The :on_duplicate_key_update option can be an array of column
    # names. The column names are the only fields that are updated if
    # a duplicate record is found. Below is an example:
    #
    #   BlogPost.import columns, values, :on_duplicate_key_update=>[ :date_modified, :content, :author ]
    #
    # ====  Using A Hash
    #
    # The :on_duplicate_key_update option can be a hash of column name
    # to model attribute name mappings. This gives you finer grained
    # control over what fields are updated with what attributes on your
    # model. Below is an example:
    #
    #   BlogPost.import columns, attributes, :on_duplicate_key_update=>{ :title => :title }
    #
    # = Returns
    # This returns an object which responds to +failed_instances+ and +num_inserts+.
    # * failed_instances - an array of objects that fails validation and were not committed to the database. An empty array if no validation is performed.
    # * num_inserts - the number of insert statements it took to import the data
    # * ids - the priamry keys of the imported ids, if the adpater supports it, otherwise and empty array.
    def import(*args)
      if args.first.is_a?( Array ) and args.first.first.is_a? ActiveRecord::Base
        options = {}
        options.merge!( args.pop ) if args.last.is_a?(Hash)

        models = args.first
        import_helper(models, options)
      else
        import_helper(*args)
      end
    end

    def import_helper( *args )
      options = { :validate=>true, :timestamps=>true, :primary_key=>primary_key }
      options.merge!( args.pop ) if args.last.is_a? Hash

      is_validating = options[:validate]
      is_validating = true unless options[:validate_with_context].nil?

      # assume array of model objects
      if args.last.is_a?( Array ) and args.last.first.is_a? ActiveRecord::Base
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
              model.read_attribute_before_type_cast(name.to_s)
            end
          # end
        end
        # supports empty array
      elsif args.last.is_a?( Array ) and args.last.empty?
        return ActiveRecord::Import::Result.new([], 0, []) if args.last.empty?
        # supports 2-element array and array
      elsif args.size == 2 and args.first.is_a?( Array ) and args.last.is_a?( Array )
        column_names, array_of_attributes = args
      else
        raise ArgumentError.new( "Invalid arguments!" )
      end

      # dup the passed in array so we don't modify it unintentionally
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
        sync_keys = options[:synchronize_keys] || [self.primary_key]
        synchronize( options[:synchronize], sync_keys)
      end
      return_obj.num_inserts = 0 if return_obj.num_inserts.nil?

      # if we have ids, then set the id on the models and mark the models as clean.
      if support_setting_primary_key_of_imported_objects?
        set_ids_and_mark_clean(models, return_obj)

        # if there are auto-save associations on the models we imported that are new, import them as well
        if options[:recursive]
          import_associations(models, options)
        end
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
    def import_with_validations( column_names, array_of_attributes, options={} )
      failed_instances = []

      # create instances for each of our column/value sets
      arr = validations_array_for_column_names_and_attributes( column_names, array_of_attributes )

      # keep track of the instance and the position it is currently at. if this fails
      # validation we'll use the index to remove it from the array_of_attributes
      arr.each_with_index do |hsh,i|
        instance = new do |model|
          hsh.each_pair{ |k,v| model.send("#{k}=", v) }
        end
        if not instance.valid?(options[:validate_with_context])
          array_of_attributes[ i ] = nil
          failed_instances << instance
        end
      end
      array_of_attributes.compact!

      (num_inserts, ids) = if array_of_attributes.empty? || options[:all_or_none] && failed_instances.any?
                      [0,[]]
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
    def import_without_validations_or_callbacks( column_names, array_of_attributes, options={} )
      column_names = column_names.map(&:to_sym)
      scope_columns, scope_values = scope_attributes.to_a.transpose

      unless scope_columns.blank?
        scope_columns.zip(scope_values).each do |name, value|
          next if column_names.include?(name.to_sym)
          column_names << name.to_sym
          array_of_attributes.each { |attrs| attrs << value }
        end
      end

      columns = column_names.each_with_index.map do |name, i|
        column = columns_hash[name.to_s]

        raise ActiveRecord::Import::MissingColumnError.new(name.to_s, i) if column.nil?

        column
      end

      columns_sql = "(#{column_names.map{|name| connection.quote_column_name(name) }.join(',')})"
      insert_sql = "INSERT #{options[:ignore] ? 'IGNORE ':''}INTO #{quoted_table_name} #{columns_sql} VALUES "
      values_sql = values_sql_for_columns_and_attributes(columns, array_of_attributes)
      ids = []
      if not supports_import?
        number_inserted = 0
        values_sql.each do |values|
          connection.execute(insert_sql + values)
          number_inserted += 1
        end
      else
        # generate the sql
        post_sql_statements = connection.post_sql_statements( quoted_table_name, options )

        # perform the inserts
        (number_inserted,ids) = connection.insert_many( [ insert_sql, post_sql_statements ].flatten,
                                                  values_sql,
                                                  "#{self.class.name} Create Many Without Validations Or Callbacks" )
      end
      [number_inserted, ids]
    end

    private

    def set_ids_and_mark_clean(models, import_result)
      unless models.nil?
        import_result.ids.each_with_index do |id, index|
          models[index].id = id.to_i
          models[index].instance_variable_get(:@changed_attributes).clear # mark the model as saved
        end
      end
    end

    def import_associations(models, options)
      # now, for all the dirty associations, collect them into a new set of models, then recurse.
      # notes:
      #    does not handle associations that reference themselves
      #    assumes that the only associations to be saved are marked with :autosave
      #    should probably take a hash to associations to follow.
      associated_objects_by_class={}
      models.each {|model| find_associated_objects_for_import(associated_objects_by_class, model) }

      associated_objects_by_class.each_pair do |class_name, associations|
        associations.each_pair do |association_name, associated_records|
          associated_records.first.class.import(associated_records, options) unless associated_records.empty?
        end
      end
    end

    # We are eventually going to call Class.import <objects> so we build up a hash
    # of class => objects to import.
    def find_associated_objects_for_import(associated_objects_by_class, model)
      associated_objects_by_class[model.class.name]||={}

      model.class.reflect_on_all_autosave_associations.each do |association_reflection|
        associated_objects_by_class[model.class.name][association_reflection.name]||=[]

        association = model.association(association_reflection.name)
        association.loaded!

        changed_objects = association.select {|a| a.new_record? || a.changed?}
        changed_objects.each do |child|
          child.send("#{association_reflection.foreign_key}=", model.id)
        end
        associated_objects_by_class[model.class.name][association_reflection.name].concat changed_objects
      end
      associated_objects_by_class
    end

    # Returns SQL the VALUES for an INSERT statement given the passed in +columns+
    # and +array_of_attributes+.
    def values_sql_for_columns_and_attributes(columns, array_of_attributes)   # :nodoc:
      # connection gets called a *lot* in this high intensity loop.
      # Reuse the same one w/in the loop, otherwise it would keep being re-retreived (= lots of time for large imports)
      connection_memo = connection
      array_of_attributes.map do |arr|
        my_values = arr.each_with_index.map do |val,j|
          column = columns[j]

          # be sure to query sequence_name *last*, only if cheaper tests fail, because it's costly
          if val.nil? && column.name == primary_key && !sequence_name.blank?
             connection_memo.next_value_for_sequence(sequence_name)
          elsif column
            if column.respond_to?(:type_cast_from_user)                         # Rails 4.2 and higher
              connection_memo.quote(column.type_cast_from_user(val), column)
            else
              connection_memo.quote(column.type_cast(val), column)              # Rails 3.1, 3.2, and 4.1
            end
          end
        end
        "(#{my_values.join(',')})"
      end
    end

    def add_special_rails_stamps( column_names, array_of_attributes, options )
      AREXT_RAILS_COLUMNS[:create].each_pair do |key, blk|
        if self.column_names.include?(key)
          value = blk.call
          if index=column_names.index(key) || index=column_names.index(key.to_sym)
            # replace every instance of the array of attributes with our value
            array_of_attributes.each{ |arr| arr[index] = value if arr[index].nil? }
          else
            column_names << key
            array_of_attributes.each { |arr| arr << value }
          end
        end
      end

      AREXT_RAILS_COLUMNS[:update].each_pair do |key, blk|
        if self.column_names.include?(key)
          value = blk.call
          if index=column_names.index(key) || index=column_names.index(key.to_sym)
             # replace every instance of the array of attributes with our value
             array_of_attributes.each{ |arr| arr[index] = value }
          else
            column_names << key
            array_of_attributes.each { |arr| arr << value }
          end

          if supports_on_duplicate_key_update?
            if options[:on_duplicate_key_update]
              options[:on_duplicate_key_update] << key.to_sym if options[:on_duplicate_key_update].is_a?(Array) && !options[:on_duplicate_key_update].include?(key.to_sym)
              options[:on_duplicate_key_update][key.to_sym] = key.to_sym if options[:on_duplicate_key_update].is_a?(Hash)
            else
              options[:on_duplicate_key_update] = [ key.to_sym ]
            end
          end
        end
      end
    end

    # Returns an Array of Hashes for the passed in +column_names+ and +array_of_attributes+.
    def validations_array_for_column_names_and_attributes( column_names, array_of_attributes ) # :nodoc:
      array_of_attributes.map do |attributes|
        Hash[attributes.each_with_index.map {|attr, c| [column_names[c], attr] }]
      end
    end

  end
end
