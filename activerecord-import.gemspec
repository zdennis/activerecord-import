Gem::Specification.new do |s|
  s.name    = 'activerecord-import'
  s.version = '0.2.3'
  s.date    = '2010-11-3'

  s.summary = "activerecord-import is a library for bulk inserting data using ActiveRecord."

  s.authors  = ['Zach Dennis']
  s.email    = 'zach.dennis@gmail.com'
  s.homepage = 'zach.dennis@gmail.com'

  s.has_rdoc = false

  s.files = Dir['Rakefile', '{lib,test}/**/*', 'README*']
  s.files &= `git ls-files -z`.split("\0") if `type -t git 2>/dev/null || which git 2>/dev/null` && $?.success?
end
