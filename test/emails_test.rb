# frozen_string_literal: true

require_relative "test_helper"

class EmailsTest < MailteaTest
  def test_send_posts_the_payload_and_returns_the_id
    sent = @mailtea.emails.send(
      from: "Acme <hello@acme.com>",
      to: "reader@acme.com",
      subject: "Hello from Ruby",
      html: "<p>Hi</p>"
    )

    assert_request "POST", "/v1/emails"
    assert_equal(
      { "from" => "Acme <hello@acme.com>", "to" => "reader@acme.com",
        "subject" => "Hello from Ruby", "html" => "<p>Hi</p>" },
      last_body
    )
    assert_equal MockMailtea::EMAIL_ID, sent["id"]
  end

  def test_send_takes_a_wire_format_hash_and_keywords_together
    @mailtea.emails.send({ "from" => "a@b.co", "subject" => "Hi" }, to: "c@d.co")

    assert_equal({ "from" => "a@b.co", "subject" => "Hi", "to" => "c@d.co" }, last_body)
  end

  def test_a_keyword_beats_the_same_key_in_the_hash
    @mailtea.emails.send({ "subject" => "from the hash" }, from: "a@b.co", to: "c@d.co",
                                                           subject: "from the keyword")

    assert_equal "from the keyword", last_body["subject"]
  end

  def test_send_carries_the_long_tail_of_optional_fields
    @mailtea.emails.send(
      from: "a@b.co",
      to: ["one@acme.com", "two@acme.com"],
      cc: "cc@acme.com",
      bcc: ["bcc@acme.com"],
      reply_to: "support@acme.com",
      subject: "Receipt",
      html: '<p>Thanks</p><img src="cid:logo" />',
      text: "Thanks",
      tags: [{ name: "category", value: "receipt" }],
      headers: { "X-Entity-Ref" => "ref_1" },
      attachments: [{ filename: "logo.png", content: "aGk=", content_type: "image/png",
                      content_id: "logo" }],
      scheduled_at: "2030-06-01T12:00:00Z",
      tracking_open: false,
      tracking_click: false,
      sender_id: nil
    )

    body = last_body
    assert_equal ["one@acme.com", "two@acme.com"], body["to"]
    assert_equal "cc@acme.com", body["cc"]
    assert_equal ["bcc@acme.com"], body["bcc"]
    assert_equal "support@acme.com", body["reply_to"]
    assert_equal [{ "name" => "category", "value" => "receipt" }], body["tags"]
    assert_equal({ "X-Entity-Ref" => "ref_1" }, body["headers"])
    assert_equal "logo", body["attachments"].first["content_id"]
    assert_equal "2030-06-01T12:00:00Z", body["scheduled_at"]
    assert_equal false, body["tracking_open"]
    assert_equal false, body["tracking_click"]
    # nil is a value, not an omission: it goes out as JSON null.
    assert body.key?("sender_id")
    assert_nil body["sender_id"]
  end

  def test_an_unpassed_keyword_is_left_out_of_the_payload
    @mailtea.emails.send(from: "a@b.co", to: "c@d.co", subject: "Hi")

    refute last_body.key?("html")
    refute last_body.key?("scheduled_at")
  end

  def test_batch_sends_a_bare_array
    result = @mailtea.emails.batch([
      { from: "a@b.co", to: "x@acme.com", subject: "1", html: "<p>1</p>" },
      { from: "a@b.co", to: "y@acme.com", subject: "2", html: "<p>2</p>" }
    ])

    assert_request "POST", "/v1/emails/batch"
    assert_kind_of Array, last_body
    assert_equal 2, last_body.length
    assert_equal "x@acme.com", last_body.first["to"]
    assert_equal 2, result["data"].length
  end

  def test_batch_refuses_anything_that_is_not_an_array
    error = assert_raises(Mailtea::Error) { @mailtea.emails.batch({ from: "a@b.co" }) }

    assert_equal "invalid_batch", error.code
    assert_equal 0, error.status
  end

  def test_get_aliases_last_event_to_status
    email = @mailtea.emails.get("txemail_abc123")

    assert_request "GET", "/v1/emails/txemail_abc123"
    assert_equal "delivered", email["last_event"]
    assert_equal "delivered", email["status"]
  end

  def test_list_builds_the_query_and_drops_nil_filters
    @mailtea.emails.list(status: "sent", limit: 10, search: "invoice", offset: nil)

    assert_request "GET", "/v1/emails"
    assert_equal({ "status" => "sent", "limit" => "10", "search" => "invoice" }, last_query)
  end

  def test_analytics_hits_its_own_path
    analytics = @mailtea.emails.analytics(from_date: "2026-01-01T00:00:00Z")

    assert_request "GET", "/v1/emails/analytics"
    assert_equal "2026-01-01T00:00:00Z", last_query["from_date"]
    assert_equal 1, analytics["delivered"]
  end

  def test_update_patches_the_scheduled_time
    @mailtea.emails.update("txemail_1", scheduled_at: "2030-06-01T12:00:00Z")

    assert_request "PATCH", "/v1/emails/txemail_1"
    assert_equal({ "scheduled_at" => "2030-06-01T12:00:00Z" }, last_body)
  end

  def test_reschedule_is_update_with_one_argument
    @mailtea.emails.reschedule("txemail_1", "2030-06-01T12:00:00Z")

    assert_request "PATCH", "/v1/emails/txemail_1"
    assert_equal({ "scheduled_at" => "2030-06-01T12:00:00Z" }, last_body)
  end

  # Cancel is POST /v1/emails/:id/cancel. The API has never had a DELETE on
  # emails, and a client that invents one fails only in production.
  def test_cancel_posts_to_the_cancel_route
    canceled = @mailtea.emails.cancel("txemail_1")

    assert_request "POST", "/v1/emails/txemail_1/cancel"
    assert_equal "canceled", canceled["last_event"]
  end
end

class InboundEmailsTest < MailteaTest
  def test_list_is_scoped_to_a_publication
    @mailtea.emails.inbound.list(publication_id: "pub_1", limit: 20)

    assert_request "GET", "/v1/emails/inbound"
    assert_equal({ "publication_id" => "pub_1", "limit" => "20" }, last_query)
  end

  def test_get_reads_one_received_email
    received = @mailtea.emails.inbound.get("insp_1")

    assert_request "GET", "/v1/emails/inbound/insp_1"
    assert_equal "inbound_email", received["object"]
  end

  def test_reply_posts_only_the_content
    reply = @mailtea.emails.inbound.reply("insp_1", html: "<p>Thanks</p>", cc: "boss@acme.com")

    assert_request "POST", "/v1/emails/inbound/insp_1/reply"
    assert_equal({ "html" => "<p>Thanks</p>", "cc" => "boss@acme.com" }, last_body)
    assert_equal MockMailtea::EMAIL_ID, reply["id"]
  end

  def test_attachments_list_and_get
    listed = @mailtea.emails.inbound.attachments.list("insp_1")
    assert_request "GET", "/v1/emails/inbound/insp_1/attachments"
    assert_equal "att_1", listed["data"].first["id"]

    attachment = @mailtea.emails.inbound.attachments.get("insp_1", "att_1")
    assert_request "GET", "/v1/emails/inbound/insp_1/attachments/att_1"
    assert_equal "https://cdn.example/a", attachment["download_url"]
  end
end
