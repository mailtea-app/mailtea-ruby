# frozen_string_literal: true

require_relative "test_helper"

class ContactsTest < MailteaTest
  def test_create_posts_the_contact
    contact = @mailtea.contacts.create(publication_id: "pub_1", email: "reader@acme.com",
                                       status: "active")

    assert_request "POST", "/v1/contacts"
    assert_equal({ "publication_id" => "pub_1", "email" => "reader@acme.com",
                   "status" => "active" }, last_body)
    assert_equal "con_1", contact["id"]
  end

  def test_upsert_is_the_same_call_as_create
    @mailtea.contacts.upsert(publication_id: "pub_1", email: "reader@acme.com")

    assert_request "POST", "/v1/contacts"
    assert_equal({ "publication_id" => "pub_1", "email" => "reader@acme.com" }, last_body)
  end

  def test_list_filters
    @mailtea.contacts.list(publication_id: "pub_1", status: "active", search: "acme", limit: 50)

    assert_request "GET", "/v1/contacts"
    assert_equal "pub_1", last_query["publication_id"]
    assert_equal "active", last_query["status"]
  end

  def test_get_by_email_escapes_the_address
    @mailtea.contacts.get("reader+tag@acme.com", publication_id: "pub_1")

    assert_equal "/v1/contacts/reader%2Btag%40acme.com", @mock.last.pathname
    assert_equal "pub_1", last_query["publication_id"]
  end

  def test_update_puts_the_publication_in_the_query_and_the_body
    @mailtea.contacts.update("con_1", publication_id: "pub_1", status: "unsubscribed")

    assert_request "PATCH", "/v1/contacts/con_1"
    assert_equal "pub_1", last_query["publication_id"]
    assert_equal({ "publication_id" => "pub_1", "status" => "unsubscribed" }, last_body)
  end

  def test_delete
    deleted = @mailtea.contacts.delete("con_1", publication_id: "pub_1")

    assert_request "DELETE", "/v1/contacts/con_1"
    assert_equal "pub_1", last_query["publication_id"]
    assert deleted["deleted"]
  end
end

class SegmentsTest < MailteaTest
  def test_create_list_get_update_delete
    created = @mailtea.segments.create(publication_id: "pub_1", name: "Engaged",
                                       status_filter: "active")
    assert_request "POST", "/v1/segments"
    assert_equal "Engaged", last_body["name"]
    assert_equal "seg_1", created["id"]

    @mailtea.segments.list(publication_id: "pub_1")
    assert_request "GET", "/v1/segments"

    @mailtea.segments.get("seg_1", publication_id: "pub_1")
    assert_request "GET", "/v1/segments/seg_1"

    @mailtea.segments.update("seg_1", publication_id: "pub_1", name: "Renamed")
    assert_request "PATCH", "/v1/segments/seg_1"
    assert_equal "pub_1", last_query["publication_id"]

    @mailtea.segments.delete("seg_1", publication_id: "pub_1")
    assert_request "DELETE", "/v1/segments/seg_1"
  end

  # Omitting a nullable filter and clearing it are different requests, and a
  # keyword defaulting to nil would make them the same one.
  def test_nil_clears_a_filter_while_omission_leaves_it_alone
    @mailtea.segments.update("seg_1", publication_id: "pub_1", status_filter: nil)
    assert last_body.key?("status_filter")
    assert_nil last_body["status_filter"]

    @mailtea.segments.update("seg_1", publication_id: "pub_1", name: "Renamed")
    refute last_body.key?("status_filter")
  end
end

class TopicsTest < MailteaTest
  def test_create_requires_the_default_subscription
    topic = @mailtea.topics.create(publication_id: "pub_1", name: "Weekly",
                                   default_subscription: "opt_in", visibility: "public")

    assert_request "POST", "/v1/topics"
    assert_equal({ "publication_id" => "pub_1", "name" => "Weekly",
                   "default_subscription" => "opt_in", "visibility" => "public" }, last_body)
    assert_equal "Weekly", topic["name"]
  end

  def test_list_get_update_delete
    @mailtea.topics.list(publication_id: "pub_1")
    assert_request "GET", "/v1/topics"

    @mailtea.topics.get("top_1", publication_id: "pub_1")
    assert_request "GET", "/v1/topics/top_1"

    @mailtea.topics.update("top_1", publication_id: "pub_1", name: "Monthly")
    assert_request "PATCH", "/v1/topics/top_1"
    assert_equal "pub_1", last_query["publication_id"]

    @mailtea.topics.delete("top_1", publication_id: "pub_1")
    assert_request "DELETE", "/v1/topics/top_1"
  end
end

class SendersTest < MailteaTest
  def test_create_list_get_update_delete
    sender = @mailtea.senders.create(publication_id: "pub_1", name: "Acme",
                                     email: "hello@acme.com", is_default: true)
    assert_request "POST", "/v1/senders"
    assert_equal true, last_body["is_default"]
    assert_equal "snd_1", sender["id"]

    @mailtea.senders.list(publication_id: "pub_1", limit: 10)
    assert_request "GET", "/v1/senders"

    @mailtea.senders.get("snd_1", publication_id: "pub_1")
    assert_request "GET", "/v1/senders/snd_1"

    # The email is immutable, so publication_id rides in the body here.
    @mailtea.senders.update("snd_1", publication_id: "pub_1", name: "Acme Support")
    assert_request "PATCH", "/v1/senders/snd_1"
    assert_equal({ "publication_id" => "pub_1", "name" => "Acme Support" }, last_body)

    @mailtea.senders.delete("snd_1", publication_id: "pub_1")
    assert_request "DELETE", "/v1/senders/snd_1"
  end
end

class SuppressionsTest < MailteaTest
  def test_list_add_and_remove_are_team_scoped
    @mailtea.suppressions.list(reason: "bounce", limit: 100)
    assert_request "GET", "/v1/suppressions"
    assert_equal "bounce", last_query["reason"]

    added = @mailtea.suppressions.add(emails: ["a@acme.com", "b@acme.com"], reason: "manual")
    assert_request "POST", "/v1/suppressions"
    assert_equal 2, added["added"]

    removed = @mailtea.suppressions.remove(emails: ["a@acme.com"])
    assert_request "DELETE", "/v1/suppressions"
    assert_equal({ "emails" => ["a@acme.com"] }, last_body)
    assert_equal 1, removed["removed"]
  end

  # The export answers text/csv, so parsing it as JSON would raise on a
  # perfectly good response.
  def test_export_returns_raw_csv_text
    csv = @mailtea.suppressions.export

    assert_request "GET", "/v1/suppressions/export"
    assert_kind_of String, csv
    assert csv.start_with?("email,reason,source,created_at")
  end
end

class ContactPropertiesTest < MailteaTest
  def test_create_list_update_delete
    property = @mailtea.contact_properties.create(key: "plan", type: "string")
    assert_request "POST", "/v1/contact-properties"
    assert_equal({ "key" => "plan", "type" => "string" }, last_body)
    assert_equal "plan", property["key"]

    @mailtea.contact_properties.list
    assert_request "GET", "/v1/contact-properties"

    @mailtea.contact_properties.update("cpr_1", description: "Billing plan", fallback_value: nil)
    assert_request "PATCH", "/v1/contact-properties/cpr_1"
    assert last_body.key?("fallback_value")
    assert_nil last_body["fallback_value"]

    @mailtea.contact_properties.delete("cpr_1")
    assert_request "DELETE", "/v1/contact-properties/cpr_1"
  end
end
