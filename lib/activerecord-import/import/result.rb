module ActiveRecord::Import #:nodoc:
  class Result
    attr_accessor :failed_instances
    attr_writer :num_inserts, :ids, :results
    def initialize(failed_instances, num_inserts, ids, results)
      @failed_instances = failed_instances
      @num_inserts = num_inserts
      @ids = ids
      @results = results
    end

    def num_inserts(with_warn: true)
      warn 'Info: ActiveRecord::Import::Result#num_inserts is not an increased record count. It is the number of inserts it took to import the data.' if with_warn
      @num_inserts ||= num_inserts
    end

    def ids(with_warn: true)
      warn_unsuppored_attribute(__method__) if adapter_name != :postgresql && with_warn
      @ids ||= ids
    end

    def results(with_warn: true)
      warn_unsuppored_attribute(__method__) if adapter_name != :postgresql && with_warn
      @results ||= results
    end

    private

    def adapter_name
      @adapter_name ||= ActiveRecord::Base.connection.adapter_name.downcase.to_sym
    end

    def warn_unsuppored_attribute(method_name)
      warn "Warning: ActiveRecord::Import::Result unsupported attribute: ##{method_name}. adaputer: #{adapter_name}"
    end
  end
end
