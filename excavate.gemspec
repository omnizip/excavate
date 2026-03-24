# frozen_string_literal: true

require_relative "lib/excavate/version"

Gem::Specification.new do |spec|
  spec.name          = "excavate"
  spec.version       = Excavate::VERSION
  spec.authors       = ["Ribose Inc."]
  spec.email         = ["open.source@ribose.com"]

  spec.summary       = "Extract nested archives with a single command."
  spec.description   = "Extract nested archives with a single command. Part of the Omnizip suite."
  spec.homepage      = "https://github.com/omnizip/excavate"
  spec.license       = "BSD-3-Clause"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.7.0")

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/omnizip/excavate"
  spec.metadata["changelog_uri"] = "https://github.com/omnizip/excavite/releases"
  spec.metadata["documentation_uri"] = "https://omnizip.github.io/excavate"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      f.match(%r{\A(?:test|spec|features|bin)/})
    end
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "cabriolet", "~> 0.2.4"
  spec.add_dependency "omnizip", "~> 0.3.9"
  spec.add_dependency "thor", "~> 1.0"

  spec.metadata["rubygems_mfa_required"] = "true"
end
