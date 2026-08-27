# frozen_string_literal: true

# The gem itself has no runtime dependencies — everything below is for running
# the tests.
source "https://rubygems.org"

gemspec

group :development, :test do
  # Both ship with Ruby as default gems; pinned here so CI resolves a known
  # version rather than whatever the runner image happens to carry.
  gem "minitest", "~> 5.20"
  gem "rake", "~> 13.0"
end
