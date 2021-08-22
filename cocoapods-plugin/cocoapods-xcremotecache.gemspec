# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'cocoapods-xcremotecache/gem_version.rb'

Gem::Specification.new do |spec|
  spec.name          = 'cocoapods-xcremotecache'
  spec.version       = CocoapodsXcremotecache::VERSION
  spec.authors       = ['Bartosz Polaczyk', 'Mark Vasiv']
  spec.email         = ['bartoszp@spotify.com', 'mvasiv@spotify.com']
  spec.description   = %q{CocoaPods plugin that enables XCRemoteCache with the project.}
  spec.summary       = %q{A simple plugin that attaches to the post_install hook and modifies the generated project to use XCRemoteCache. Supports both producing anc consuming parts.}
  spec.homepage      = 'https://github.com/spotify/XCRemoteCache'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']
end
