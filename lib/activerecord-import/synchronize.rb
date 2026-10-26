# frozen_string_literal: true

module ActiveRecord # :nodoc:
  class Base # :nodoc:
    # Synchronizes the passed in ActiveRecord instances with data
    # from the database. This is like calling reload on an individual
    # ActiveRecord instance but it is intended for use on multiple instances.
    #
    # This uses one query for all instance updates and then updates existing
    # instances rather sending one query for each instance
    #
    # == Examples
    # # Synchronizing existing models by matching on the primary key field
    # posts = Post.where(author: "Zach").first
    # <.. out of system changes occur to change author name from Zach to Zachary..>
    # Post.synchronize posts
    # posts.first.author # => "Zachary" instead of Zach
    #
    # # Synchronizing using custom key fields
    # posts = Post.where(author: "Zach").first
    # <.. out of system changes occur to change the address of author 'Zach' to 1245 Foo Ln ..>
    # Post.synchronize posts, [:name] # queries on the :name column and not the :id column
    # posts.first.address # => "1245 Foo Ln" instead of whatever it was
    #
    def self.synchronize(instances, keys = [primary_key])
      return if instances.empty?

      synchronize_instances(instances, keys) do |instance, fresh_attributes|
        instance.instance_variable_set :@attributes, fresh_attributes
        instance.clear_changes_information
      end
      instances
    end

    # Finds the records matching the passed in +instances+ on +keys+ and
    # yields each instance that has one together with the attributes of
    # its record, for the block to update the instance with. Returns the
    # instances that had a matching record.
    def self.synchronize_instances(instances, keys) # :nodoc:
      return [] if instances.empty?

      conditions = {}

      key_values = keys.map { |key| instances.map(&key.to_sym).uniq }
      keys.zip(key_values).each { |key, values| conditions[key] = values }
      order = keys.map { |key| "#{key} ASC" }.join(",")

      klass = instances.first.class

      fresh_instances = klass.unscoped.where(conditions).order(order)
      fresh_instances_by_key = fresh_instances.each_with_object({}) do |fresh_instance, records_by_key|
        key = keys.map { |key_column| fresh_instance.send(key_column) }
        records_by_key[key] ||= fresh_instance
      end

      instances.select do |instance|
        key = keys.map { |key_column| instance.send(key_column) }
        matched_instance = fresh_instances_by_key[key]

        next false unless matched_instance

        instance.instance_variable_set :@association_cache, {}
        # Aggregations is only included in models that call composed_of
        instance.send :clear_aggregation_cache if instance.respond_to?(:clear_aggregation_cache, true)
        yield instance, matched_instance.instance_variable_get(:@attributes)

        # Since the instance now accurately reflects the record in
        # the database, ensure that instance.persisted? is true.
        instance.instance_variable_set '@new_record', false
        instance.instance_variable_set '@destroyed', false
        true
      end
    end
    private_class_method :synchronize_instances

    # See ActiveRecord::ConnectionAdapters::AbstractAdapter.synchronize
    def synchronize(instances, key = [ActiveRecord::Base.primary_key])
      self.class.synchronize(instances, key)
    end
  end
end
