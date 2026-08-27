# frozen_string_literal: true

require_relative "test_helper"

class DomainsTest < MailteaTest
  def test_create_list_get_verify_update_delete
    created = @mailtea.domains.create(publication_id: "pub_1", name: "acme.com",
                                      purpose: "email")
    assert_request "POST", "/v1/domains"
    assert_equal "acme.com", last_body["name"]
    assert_equal "dom_1", created["id"]

    @mailtea.domains.list(publication_id: "pub_1")
    assert_request "GET", "/v1/domains"

    @mailtea.domains.get("dom_1", publication_id: "pub_1")
    assert_request "GET", "/v1/domains/dom_1"

    verified = @mailtea.domains.verify("dom_1", publication_id: "pub_1")
    assert_request "POST", "/v1/domains/dom_1/verify"
    assert_equal "pub_1", last_query["publication_id"]
    assert_equal "verified", verified["status"]

    @mailtea.domains.update("dom_1", publication_id: "pub_1", custom_return_path: "bounces")
    assert_request "PATCH", "/v1/domains/dom_1"
    assert_equal "pub_1", last_query["publication_id"]
    assert_equal "bounces", last_body["custom_return_path"]

    @mailtea.domains.delete("dom_1", publication_id: "pub_1")
    assert_request "DELETE", "/v1/domains/dom_1"
  end

  def test_tracking_subdomains
    created = @mailtea.domains.tracking.create("dom_1", publication_id: "pub_1",
                                                        subdomain: "links")
    assert_request "POST", "/v1/domains/dom_1/tracking-domains"
    assert_equal "pub_1", last_query["publication_id"]
    # publication_id is the scope, not part of the record being created.
    assert_equal({ "subdomain" => "links" }, last_body)
    assert_equal "trk_1", created["id"]

    @mailtea.domains.tracking.list("dom_1", publication_id: "pub_1")
    assert_request "GET", "/v1/domains/dom_1/tracking-domains"

    @mailtea.domains.tracking.verify("dom_1", "trk_1", publication_id: "pub_1")
    assert_request "POST", "/v1/domains/dom_1/tracking-domains/trk_1/verify"

    @mailtea.domains.tracking.delete("dom_1", "trk_1", publication_id: "pub_1")
    assert_request "DELETE", "/v1/domains/dom_1/tracking-domains/trk_1"
  end
end

class WebhooksTest < MailteaTest
  def test_create_returns_the_signing_secret_once
    endpoint = @mailtea.webhooks.create(publication_id: "pub_1",
                                        url: "https://acme.com/hooks",
                                        events: ["email.delivered"])

    assert_request "POST", "/v1/webhooks/endpoints"
    assert_equal ["email.delivered"], last_body["events"]
    assert endpoint["signing_secret"].start_with?("whsec_")
  end

  def test_list_get_update_delete
    @mailtea.webhooks.list(publication_id: "pub_1")
    assert_request "GET", "/v1/webhooks/endpoints"

    @mailtea.webhooks.get("whe_1", publication_id: "pub_1")
    assert_request "GET", "/v1/webhooks/endpoints/whe_1"

    @mailtea.webhooks.update("whe_1", publication_id: "pub_1", enabled: false)
    assert_request "PATCH", "/v1/webhooks/endpoints/whe_1"
    assert_equal "pub_1", last_query["publication_id"]
    assert_equal false, last_body["enabled"]

    @mailtea.webhooks.delete("whe_1", publication_id: "pub_1")
    assert_request "DELETE", "/v1/webhooks/endpoints/whe_1"
  end
end

class ApiKeysTest < MailteaTest
  def test_create_list_revoke
    key = @mailtea.api_keys.create(name: "CI", permission: "sending_access")
    assert_request "POST", "/v1/api-keys"
    assert_equal({ "name" => "CI", "permission" => "sending_access" }, last_body)
    assert_equal "mt_pat_returned_once", key["token"]

    @mailtea.api_keys.list
    assert_request "GET", "/v1/api-keys"
    assert_nil last_query["publication_id"]

    @mailtea.api_keys.revoke("key_1")
    assert_request "DELETE", "/v1/api-keys/key_1"
  end
end
