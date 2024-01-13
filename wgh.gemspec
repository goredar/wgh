# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'wgh/version'

Gem::Specification.new do |spec|
  spec.name          = "wgh"
  spec.version       = Wgh::VERSION
  spec.authors       = ["v_sazonenko"]
  spec.email         = ["v_sazonenko@wargaming.net"]
  spec.summary       = %q{WGH - WG Host Information Tool}
  spec.description   = %q{wgh tool provides information about production hosts}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "rake", "~> 10"

  spec.add_runtime_dependency "curb", "~> 0"
  spec.add_runtime_dependency "oj", "~> 2.13"
  spec.add_runtime_dependency "goredar", "~> 0"
  spec.add_runtime_dependency "spreadsheet", "~> 1.0"
  spec.add_runtime_dependency "terminal-table", "~> 1"
  spec.add_runtime_dependency "colorize", "~> 0"
#  spec.add_runtime_dependency "mysql2", "~> 0"
  spec.add_runtime_dependency "mongo", "~> 2.1"
  spec.add_runtime_dependency "psych", "= 2.0.8"
  spec.add_runtime_dependency "bundler", "~> 1.10"
end