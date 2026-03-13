# frozen_string_literal: true

require_relative "lib/siftly/version"

Gem::Specification.new do |spec|
  spec.name = "siftly"
  spec.version = Siftly::VERSION
  spec.authors = ["Tomos Rees"]

  spec.summary = "Composable spam filtering core for Ruby applications."
  spec.description = "Siftly provides a small, framework-agnostic core for registering spam filters, executing pipelines, and aggregating structured results."
  spec.homepage = "https://github.com/tomosjohnrees/siftly"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir.glob("lib/**/*") + %w[CHANGELOG.md LICENSE README.md siftly.gemspec]
  spec.bindir = "exe"
  spec.require_paths = ["lib"]

  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "rake", "~> 13.0"
end
