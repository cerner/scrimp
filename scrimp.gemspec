# -*- encoding: utf-8 -*-
require File.expand_path('../lib/scrimp/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Jacob Williams"]
  gem.email         = ["jacob.williams@cerner.com"]
  gem.description   = %q{Web UI for making requests to thrift services, given their IDL files.}
  gem.summary       = %q{Generic UI for thrift services.}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "scrimp"
  gem.require_paths = ["lib"]
  gem.version       = Scrimp::VERSION

  gem.add_runtime_dependency 'thrift', '~> 0.9.1'
  gem.add_runtime_dependency 'thin', '~> 1.6.0' # https://issues.apache.org/jira/browse/THRIFT-2145
  gem.add_runtime_dependency 'haml', '~> 4.0.3'
  gem.add_runtime_dependency 'json', '~> 1.8.1'
  gem.add_runtime_dependency 'sinatra', '~> 1.4.4'
end
