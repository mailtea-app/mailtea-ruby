# frozen_string_literal: true

# Mailtea::VERSION must not lie.
#
# The gem's version, the CHANGELOG's newest heading and the User-Agent every
# request carries are three copies of one number. The gemspec reads the constant
# so those two cannot drift, but the CHANGELOG and the User-Agent can — and a
# release that ships 0.2.0 while introducing itself as 0.1.0 keeps working
# perfectly and puts the wrong number in every bug report filed against it. Two
# sibling packages in the Mailtea monorepo have done exactly that.

require "minitest/autorun"
require "mailtea"

class VersionTest < Minitest::Test
  def root
    File.expand_path("..", __dir__)
  end

  def test_the_version_is_a_release_number
    assert_match(/\A\d+\.\d+\.\d+\z/, Mailtea::VERSION)
  end

  def test_the_gemspec_publishes_the_constant
    gemspec = File.read(File.join(root, "mailtea.gemspec"))

    assert_includes gemspec, "Mailtea::VERSION",
                    "the gemspec must read the constant, not a second copy of the number"
  end

  def test_the_changelog_documents_this_version
    changelog = File.read(File.join(root, "CHANGELOG.md"))
    newest = changelog[/^## (\d+\.\d+\.\d+)/, 1]

    assert_equal Mailtea::VERSION, newest,
                 "CHANGELOG.md's newest entry is #{newest.inspect} but the gem is " \
                 "#{Mailtea::VERSION}. The GitHub release notes are generated from that " \
                 "section, so a missing entry is a missing release note."
  end

  def test_requests_introduce_themselves_with_this_version
    sent = []
    transport = lambda do |_method, _url, headers, _body|
      sent << headers["User-Agent"]
      Mailtea::HttpResponse.new(status: 200, headers: {}, body: "{}")
    end

    Mailtea::Client.new("mt_pat_test", base_url: "https://api.mailtea.app", transport: transport)
            .emails.list

    assert_equal ["mailtea-ruby/#{Mailtea::VERSION}"], sent
  end
end
