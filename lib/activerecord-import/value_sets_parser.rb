module ActiveRecord::Import
  class ValueSetsBytesParser
    attr_reader :reserved_bytes, :max_bytes, :values

    def self.parse(values, options)
      new(values, options).parse
    end

    def initialize(values, options)
      @values = values
      @reserved_bytes = options[:reserved_bytes]
      @max_bytes = options[:max_bytes]
    end

    def parse
      value_sets = []
      arr, current_arr_values_size, current_size = [], 0, 0
      values.each_with_index do |val,i|
        comma_bytes = arr.size
        bytes_thus_far = reserved_bytes + current_size + val.bytesize + comma_bytes
        if bytes_thus_far <= max_bytes
          current_size += val.bytesize
          arr << val
        else
          value_sets << arr
          arr = [ val ]
          current_size = val.bytesize
        end

        # if we're on the last iteration push whatever we have in arr to value_sets
        value_sets << arr if i == (values.size-1)
      end

      [ *value_sets ]
    end
  end

  class ValueSetsRecordsParser
    attr_reader :max_records, :values

    def self.parse(values, options)
      new(values, options).parse
    end

    def initialize(values, options)
      @values = values
      @max_records = options[:max_records]
    end

    def parse
      @values.in_groups_of(max_records, with_fill=false)
    end
  end
end
