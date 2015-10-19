$LOAD_PATH.push File.expand_path('../lib', __FILE__)

# Maintain your gem's version:
require 'rrapid/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = 'rrapid'
  s.version     = API::VERSION
  s.authors     = ['Michael Chittenden', 'Quirky Platform Team']
  s.email       = ['mchitten@gmail.com', 'platform@quirky.com']
  s.homepage    = 'https://www.mchitten.com'
  s.summary     = 'Rapid Ruby API Development'
  s.description = 'RRapid provides a base framework to help promote rapid API development.'

  s.files = Dir['{app,config,db,lib}/**/*', 'Rakefile', 'README.rdoc']

  s.add_dependency 'active_model_serializers', '0.8.2'
  s.add_dependency 'will_paginate', '3.0.6'
  s.add_dependency 'newrelic_rpm'
  s.add_dependency 'hirb'
  s.add_dependency 'responders'

  s.add_development_dependency 'faker'
  s.add_development_dependency 'rails', '4.2'
  s.add_development_dependency 'sqlite3'
  s.add_development_dependency 'rspec-rails'
  s.add_development_dependency 'capybara'
  s.add_development_dependency 'factory_girl_rails'
end
