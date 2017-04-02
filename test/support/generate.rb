class ActiveSupport::TestCase
  def Build(*args) # rubocop:disable Style/MethodName
    n = args.shift if args.first.is_a?(Numeric)
    factory = args.shift
    factory_girl_args = args.shift || {}

    if n
      [].tap do |collection|
        n.times.each { collection << FactoryGirl.build(factory.to_s.singularize.to_sym, factory_girl_args) }
      end
    else
      FactoryGirl.build(factory.to_s.singularize.to_sym, factory_girl_args)
    end
  end

  def Generate(*args) # rubocop:disable Style/MethodName
    n = args.shift if args.first.is_a?(Numeric)
    factory = args.shift
    factory_girl_args = args.shift || {}

    if n
      [].tap do |collection|
        n.times.each { collection << FactoryGirl.create(factory.to_s.singularize.to_sym, factory_girl_args) }
      end
    else
      FactoryGirl.create(factory.to_s.singularize.to_sym, factory_girl_args)
    end
  end
end
