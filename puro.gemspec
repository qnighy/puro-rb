# frozen_string_literal: true

require_relative "lib/puro/version"

Gem::Specification.new do |spec|
  spec.name = "puro"
  spec.version = Puro::VERSION
  spec.authors = ["Masaki Hara"]
  spec.email = ["ackie.h.gmai@gmail.com"]

  spec.summary = "WebSocket client"
  spec.description = "Puro is a WebSocket client that tries to expose appropriately abstracted APIs."
  spec.homepage = "https://github.com/qnighy/puro-rb"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org/"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/qnighy/puro-rb"
  spec.metadata["changelog_uri"] = "https://github.com/qnighy/puro-rb/blob/master/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) || f.start_with?("bin/", "test/", "spec/", "sig/spec/", "features/", ".git",
                                                         ".circleci", "appveyor")
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "websocket", "~> 1.0"
end
