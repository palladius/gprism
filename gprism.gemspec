# frozen_string_literal: true

version_file = File.expand_path("VERSION", __dir__)
version = File.exist?(version_file) ? File.read(version_file).strip : "0.3.9"

Gem::Specification.new do |spec|
  spec.name          = "gprism"
  spec.version       = version
  spec.authors       = ["Riccardo Carlesso"]
  spec.email         = ["132802+palladius@users.noreply.github.com"]

  spec.summary       = "Git-Privatize Replacement In Secret Manager (and GCS)"
  spec.description   = "Encrypts and syncs repository secrets across GCP Secret Manager, Google Cloud Storage, and local encrypted files."
  spec.homepage      = "https://github.com/palladius/gprism"
  spec.license       = "Apache-2.0"

  spec.required_ruby_version = ">= 2.7.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/palladius/gprism"
  spec.metadata["changelog_uri"] = "https://github.com/palladius/gprism/blob/main/CHANGELOG.md"

  spec.files = Dir.glob("{bin,lib,docs}/**/*") + %w[LICENSE README.md VERSION CHANGELOG.md]
  spec.bindir        = "bin"
  spec.executables   = ["gprism"]
  spec.require_paths = ["lib"]
end
