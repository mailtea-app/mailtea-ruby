# frozen_string_literal: true

require_relative "test_helper"

# Domain claims — take a domain back from the team that currently holds it.
class DomainClaimsTest < MailteaTest
  def test_create_posts_the_claim
    claim = @mailtea.domains.claims.create(publication_id: "pub_1", name: "acme.com",
                                           region: "eu-west-1")

    assert_request "POST", "/v1/domains/claim"
    assert_equal({ "publication_id" => "pub_1", "name" => "acme.com",
                   "region" => "eu-west-1" }, last_body)
    # The TXT record to publish arrives in records[], never as a bare txt field.
    assert_equal "Claim", claim["records"][0]["record"]
    assert_equal "pending", claim["status"]
  end

  def test_get_scopes_by_publication
    @mailtea.domains.claims.get("clm_1", publication_id: "pub_1")

    assert_request "GET", "/v1/domains/claims/clm_1"
    assert_equal "pub_1", last_query["publication_id"]
  end

  def test_verify_posts_the_verify_subpath
    verified = @mailtea.domains.claims.verify("clm_1", publication_id: "pub_1")

    assert_request "POST", "/v1/domains/claims/clm_1/verify"
    assert_equal "pub_1", last_query["publication_id"]
    # A completed claim answers with the fresh domain beside it, so the claimant
    # can publish its DNS without a second request.
    assert_equal "dom_2", verified["domain"]["id"]
    assert_equal "dom_2", verified["domain_id"]
  end

  def test_cancel_deletes_the_claim
    @mailtea.domains.claims.cancel("clm_1", publication_id: "pub_1")

    assert_request "DELETE", "/v1/domains/claims/clm_1"
    assert_equal "pub_1", last_query["publication_id"]
  end

  def test_the_claim_id_is_escaped_into_its_path_segment
    @mailtea.domains.claims.get("clm/1", publication_id: "pub_1")

    assert_request "GET", "/v1/domains/claims/clm%2F1"
  end

  # Pass-through: the multi-region fields need no code, and this is what fails
  # if that ever stops being true.
  def test_create_forwards_region_tls_and_tracking_subdomain
    @mailtea.domains.create(publication_id: "pub_1", name: "acme.com",
                            region: "ap-southeast-1", tls: "enforced",
                            tracking_subdomain: "links")

    assert_equal "ap-southeast-1", last_body["region"]
    assert_equal "enforced", last_body["tls"]
    assert_equal "links", last_body["tracking_subdomain"]
  end

  def test_update_forwards_tls_and_tracking_subdomain
    @mailtea.domains.update("dom_1", publication_id: "pub_1", tls: "enforced",
                                     tracking_subdomain: "links")

    assert_request "PATCH", "/v1/domains/dom_1"
    assert_equal "enforced", last_body["tls"]
    assert_equal "links", last_body["tracking_subdomain"]
  end

  # The removal has to reach the wire AS null. The query builder drops nils; the
  # body must not, or "remove it" becomes "leave it alone" and the caller gets a
  # 200 saying nothing happened.
  def test_update_sends_an_explicit_nil_to_clear_the_tracking_subdomain
    @mailtea.domains.update("dom_1", publication_id: "pub_1", tracking_subdomain: nil)

    assert_request "PATCH", "/v1/domains/dom_1"
    assert_equal "pub_1", last_query["publication_id"]
    assert last_body.key?("tracking_subdomain"), "the key must be present, not merely nil-ish"
    assert_nil last_body["tracking_subdomain"]
  end

  # Three states, not two: an absent key leaves the subdomain alone, nil removes
  # it. A body that always carried the key would clear it on every update.
  def test_update_omits_the_tracking_subdomain_when_it_is_not_named
    @mailtea.domains.update("dom_1", publication_id: "pub_1", tls: "enforced")

    refute last_body.key?("tracking_subdomain")
  end

  def test_list_forwards_the_region_and_status_filters
    @mailtea.domains.list(publication_id: "pub_1", region: "eu-west-1", status: "verified")

    assert_request "GET", "/v1/domains"
    assert_equal "eu-west-1", last_query["region"]
    assert_equal "verified", last_query["status"]
  end
end
