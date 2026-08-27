# frozen_string_literal: true

require "minitest/autorun"
require "mailtea"

# Endpoint parity with the reference implementation.
#
# The Mailtea Python SDK is the canonical surface every other SDK is ported
# from. This list is the complete set of `/v1/...` path templates it calls,
# extracted in the Mailtea monorepo with:
#
#     grep -ohE '"/v1/[^"]*"' sdks/python/mailtea/*.py | sort -u
#
# It is hardcoded here on purpose: this repository is a standalone mirror, so a
# test that reached for the Python source would be dead on arrival after the
# first clone. If the API grows an endpoint, add it here in the same shape the
# grep produces — a trailing slash means the path continues with an id.
class EndpointParityTest < Minitest::Test
  PYTHON_ENDPOINTS = [
    "/v1/api-keys",
    "/v1/api-keys/",
    "/v1/assets",
    "/v1/assets/",
    "/v1/automations",
    "/v1/automations/",
    "/v1/automations/validate",
    "/v1/contact-properties",
    "/v1/contact-properties/",
    "/v1/contacts",
    "/v1/contacts/",
    "/v1/domains",
    "/v1/domains/",
    "/v1/emails",
    "/v1/emails/",
    "/v1/emails/analytics",
    "/v1/emails/batch",
    "/v1/emails/inbound",
    "/v1/event-definitions",
    "/v1/event-definitions/",
    "/v1/events",
    "/v1/posts",
    "/v1/posts/",
    "/v1/segments",
    "/v1/segments/",
    "/v1/senders",
    "/v1/senders/",
    "/v1/suppressions",
    "/v1/suppressions/export",
    "/v1/templates",
    "/v1/templates/",
    "/v1/templates/render",
    "/v1/topics",
    "/v1/topics/",
    "/v1/webhooks/endpoints"
  ].freeze

  # Every resource the client exposes, and the methods on it that the README's
  # API table promises. A path can exist in the source while nothing calls it,
  # so this is the half of parity the grep cannot see.
  SURFACE = {
    "emails" => %i[send batch get list analytics update reschedule cancel inbound],
    "contacts" => %i[create upsert list get update delete],
    "posts" => %i[create list get update delete send send_test],
    "segments" => %i[create list get update delete],
    "senders" => %i[create list get update delete],
    "assets" => %i[upload list delete],
    "suppressions" => %i[list add remove export],
    "topics" => %i[create list get update delete],
    "templates" => %i[render create list get update publish unpublish versions
                      restore_version duplicate delete],
    "domains" => %i[create list get verify update delete tracking],
    "webhooks" => %i[create list get update delete],
    "contact_properties" => %i[create list update delete],
    "api_keys" => %i[create list revoke],
    "automations" => %i[validate create list get update delete activate pause archive
                        versions version metrics test],
    "automation_runs" => %i[list get cancel],
    "events" => %i[send list],
    "event_definitions" => %i[create list get update delete]
  }.freeze

  def ruby_endpoints
    root = File.expand_path("../lib", __dir__)
    Dir.glob(File.join(root, "**", "*.rb")).flat_map do |file|
      # Paths are built by concatenation rather than interpolation precisely so
      # they stay greppable literals, here and in the Python SDK.
      File.read(file).scan(%r{"(/v1/[^"#]*)"}).flatten
    end.uniq.sort
  end

  def test_every_python_endpoint_is_reachable_from_this_sdk
    missing = PYTHON_ENDPOINTS - ruby_endpoints

    assert_empty missing,
                 "the Python SDK reaches #{missing.length} endpoint(s) this one does not: " \
                 "#{missing.join(", ")}"
  end

  def test_the_endpoints_this_sdk_adds_are_deliberate
    # Not a failure — extra paths are how the SDK grows. Listing them keeps a
    # typo ("/v1/contact_properties") from passing as new surface.
    extra = ruby_endpoints - PYTHON_ENDPOINTS

    assert_empty extra,
                 "unexpected endpoint(s): #{extra.join(", ")}. If they are real, add them " \
                 "to PYTHON_ENDPOINTS with the release that introduced them."
  end

  def test_every_resource_and_method_is_wired_to_the_client
    client = Mailtea::Client.new("mt_pat_test", base_url: "https://api.mailtea.app")

    SURFACE.each do |resource, methods|
      assert client.respond_to?(resource), "Mailtea::Client has no ##{resource}"
      target = client.public_send(resource)
      methods.each do |method|
        assert target.respond_to?(method), "#{resource} has no ##{method}"
      end
    end
  end

  def test_the_inbound_sub_resources_are_wired
    client = Mailtea::Client.new("mt_pat_test", base_url: "https://api.mailtea.app")

    %i[list get reply attachments].each do |method|
      assert client.emails.inbound.respond_to?(method)
    end
    %i[list get].each do |method|
      assert client.emails.inbound.attachments.respond_to?(method)
    end
    %i[create list verify delete].each do |method|
      assert client.domains.tracking.respond_to?(method)
    end
  end
end
