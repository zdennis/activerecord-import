class ActiveSupport::TestCase
  def Build(*args)
    n = args.shift if args.first.is_a?(Numeric)
    factory = args.shift
    factory_girl_args = args.shift || {}

    if n
      Array.new.tap do |collection|
        n.times.each { collection << FactoryGirl.build(factory.to_s.singularize.to_sym, factory_girl_args) }
      end
    else
      FactoryGirl.build(factory.to_s.singularize.to_sym, factory_girl_args)
    end
  end

  def Generate(*args)
    n = args.shift if args.first.is_a?(Numeric)
    factory = args.shift
    factory_girl_args = args.shift || {}

    if n
      Array.new.tap do |collection|
        n.times.each { collection << FactoryGirl.create(factory.to_s.singularize.to_sym, factory_girl_args) }
      end
    else
      FactoryGirl.create(factory.to_s.singularize.to_sym, factory_girl_args)
    end
  end
end
