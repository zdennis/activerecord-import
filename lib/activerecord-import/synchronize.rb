module ActiveRecord # :nodoc:
  class Base # :nodoc:
      
    # Synchronizes the passed in ActiveRecord instances with data
    # from the database. This is like calling reload
    # on an individual ActiveRecord instance but it is intended for use on
    # multiple instances. 
    #
    # This uses one query for all instance updates and then updates existing
    # instances rather sending one query for each instance
    def self.synchronize(instances, keys=[self.primary_key])
      return if instances.empty?

      conditions = {}
      order = ""
      
      key_values = keys.map { |key| instances.map(&"#{key}".to_sym) }
      keys.zip(key_values).each { |key, values| conditions[key] = values }
      order = keys.map{ |key| "#{key} ASC" }.join(",")
      
      klass = instances.first.class

      fresh_instances = klass.find( :all, :conditions=>conditions, :order=>order )
      instances.each do |instance|
        matched_instance = fresh_instances.detect do |fresh_instance|
          keys.all?{ |key| fresh_instance.send(key) == instance.send(key) }
        end
        
        if matched_instance
          instance.clear_aggregation_cache
          instance.clear_association_cache
          instance.instance_variable_set '@attributes', matched_instance.attributes
        end
      end
    end

    # See ActiveRecord::ConnectionAdapters::AbstractAdapter.synchronize
    def synchronize(instances, key=ActiveRecord::Base.primary_key)
      self.class.synchronize(instances, key)
    end
  end
end