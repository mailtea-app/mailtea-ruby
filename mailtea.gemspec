# frozen_string_literal: true

require_relative "lib/mailtea/version"

Gem::Specification.new do |spec|
  spec.name = "mailtea"
  spec.version = Mailtea::VERSION
  spec.summary = "Mailtea Ruby SDK — send, schedule, and manage email from your app or AI agent."
  spec.description = "The official Ruby SDK for Mailtea: a thin, zero-dependency wrapper " \
                     "over the Mailtea REST API, built on net/http and json."
  spec.authors = ["Mailtea"]
  spec.homepage = "https://mailtea.app"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0"

  spec.metadata = {
    "homepage_uri" => "https://mailtea.app",
    "documentation_uri" => "https://docs.mailtea.app",
    "source_code_uri" => "https://github.com/mailtea-app/mailtea-ruby",
    "changelog_uri" => "https://github.com/mailtea-app/mailtea-ruby/blob/main/CHANGELOG.md",
    "bug_tracker_uri" => "https://github.com/mailtea-app/mailtea-ruby/issues",
    "rubygems_mfa_required" => "true"
  }

  # Globbed rather than shelled out to `git ls-files`, so the gem builds from a
  # tarball or any checkout without git on PATH.
  spec.files = Dir["lib/**/*.rb"] + %w[README.md CHANGELOG.md LICENSE]
  spec.require_paths = ["lib"]

  # No runtime dependencies. net/http, json, uri and openssl ship with Ruby.
end
