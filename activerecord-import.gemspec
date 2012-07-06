# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name        = "activerecord-import"
  s.version     = '0.2.8'
  s.platform    = Gem::Platform::RUBY  
  s.summary     = "activerecord-import is a library for bulk inserting data using ActiveRecord."
  s.email       = "zach.dennis@gmail.com"
  s.homepage    = "https://github.com/zdennis/activerecord-import/wiki/"
  s.description = "activerecord-import is a library for bulk inserting data using ActiveRecord."
  s.authors     = ['Zach Dennis']

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {spec}/*`.split("\n")
  s.require_paths = ["lib"]

  s.add_dependency("activerecord", ">= 3.0")
end