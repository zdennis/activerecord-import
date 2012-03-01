# -*- encoding: utf-8 -*-
$:.push File.expand_path('../lib/', __FILE__)

Gem::Specification.new do |s|
  s.name        = "activerecord-import"
  s.version     = "0.2.9"
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Zach Dennis"]
  s.email       = ["zach.dennis@gmail.com"]
  s.homepage    = "http://github.com/zdennis/activerecord-import"
  s.summary     = "Bulk-loading extension for ActiveRecord"
  s.description = "Extraction of the ActiveRecord::Base#import functionality from ar-extensions for Rails 3 and beyond"
 
  s.rubyforge_project = "activerecord-import"

  s.require_paths= ['lib']
end
