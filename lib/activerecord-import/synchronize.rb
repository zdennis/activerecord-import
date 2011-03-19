module ActiveRecord # :nodoc:
  class Base # :nodoc:
      
    # Synchronizes the passed in ActiveRecord instances with data
    # from the database. This is like calling reload
    # on an individual ActiveRecord instance but it is intended for use on
    # multiple instances. 
    #
    # This uses one query for all instance updates and then updates existing
    # instances rather sending one query for each instance
    def self.synchronize(instances, key=self.primary_key)
      return if instances.empty?
      
      keys = instances.map(&"#{key}".to_sym)
      klass = instances.first.class
      fresh_instances = klass.find( :all, :conditions=>{ key=>keys }, :order=>"#{key} ASC" )

      instances.each_with_index do |instance, index|
        instance.clear_aggregation_cache
        instance.clear_association_cache
        instance.instance_variable_set '@attributes', fresh_instances[index].attributes
      end
    end

    # See ActiveRecord::ConnectionAdapters::AbstractAdapter.synchronize
    def synchronize(instances, key=ActiveRecord::Base.primary_key)
      self.class.synchronize(instances, key)
    end
  end
end