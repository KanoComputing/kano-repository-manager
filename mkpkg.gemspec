# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'mkpkg/version'

Gem::Specification.new do |spec|
  spec.name          = "mkpkg"
  spec.version       = Mkpkg::VERSION
  spec.authors       = ["Radek Pazdera"]
  spec.email         = ["radek@kano.me"]
  spec.summary       = %q{mkpkg is a packaging tool that helps you make,
                          distribute and maintain you own disto packages.}
  spec.description   = %q{This tool works with distribution-level packaging
                          systems (the only one supported at this point is
                          the Debian one) and helps you to create, maintain,
                          and distribute your own packages through your
                          own repositories.}
  spec.homepage      = "http://github.com/KanoComputing/"
  spec.license       = "GPLv2"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "thor", "~> 0.18.1"

  spec.add_development_dependency "bundler", "~> 1.5"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
end
