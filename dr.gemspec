# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'dr/version'

Gem::Specification.new do |spec|
  spec.name          = "dr"
  spec.version       = Dr::VERSION
  spec.authors       = ["Radek Pazdera"]
  spec.email         = ["radek@kano.me"]
  spec.summary       = %q{dr stands for debian-repository. It is a packaging
                          tool that helps you make, distribute and maintain
                          you own disto packages and repositories. It's in a
                          very early stage, NOT READY for production.}
  spec.description   = %q{dr works with distribution-level packaging
                          tools and helps you make and distribute your own
                          Debian packages through your own repository.
                          This is a super early release, certainly NOT ready
                          for production.}
  spec.homepage      = "http://github.com/KanoComputing/kano-package-system"
  spec.license       = "GPLv2"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "thor", "~> 0.18", "< 0.19.2"
  spec.add_dependency "tco", "~> 0.1"
  spec.add_dependency "octokit", "~> 3.3"
  spec.add_dependency "rack", "~> 1.6", ">= 1.6.4"
  spec.add_dependency "thin", "~> 1.6", ">= 1.6.3"

  spec.add_development_dependency "bundler", "~> 1.11", ">= 1.11.2"
  spec.add_development_dependency "rake", "~> 10.3"
  spec.add_development_dependency "rspec", "~> 3.1"
end
