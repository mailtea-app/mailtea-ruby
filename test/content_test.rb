# frozen_string_literal: true

require_relative "test_helper"

class PostsTest < MailteaTest
  def test_create_takes_a_template_or_inline_html
    post = @mailtea.posts.create(publication_id: "pub_1", subject: "Issue 1",
                                 template_id: "tpl_1", variables: { "name" => "Ada" },
                                 kind: "newsletter")

    assert_request "POST", "/v1/posts"
    assert_equal "tpl_1", last_body["template_id"]
    assert_equal({ "name" => "Ada" }, last_body["variables"])
    assert_equal "post_1", post["id"]
  end

  def test_create_can_send_immediately
    @mailtea.posts.create(publication_id: "pub_1", subject: "Issue 1", html: "<p>Hi</p>",
                          send: true)

    assert_equal true, last_body["send"]
  end

  def test_list_get_update_delete
    @mailtea.posts.list(publication_id: "pub_1", kind: "broadcast", limit: 5)
    assert_request "GET", "/v1/posts"
    assert_equal "broadcast", last_query["kind"]

    @mailtea.posts.get("post_1")
    assert_request "GET", "/v1/posts/post_1"

    @mailtea.posts.update("post_1", subject: "Issue 1 (fixed)")
    assert_request "PATCH", "/v1/posts/post_1"
    assert_equal({ "subject" => "Issue 1 (fixed)" }, last_body)

    @mailtea.posts.delete("post_1", publication_id: "pub_1")
    assert_request "DELETE", "/v1/posts/post_1"
  end

  def test_send_with_and_without_a_schedule
    sending = @mailtea.posts.send("post_1")
    assert_request "POST", "/v1/posts/post_1/send"
    assert_nil last_body, "an unscheduled send should carry no body"
    assert_equal "sending", sending["status"]

    @mailtea.posts.send("post_1", scheduled_at: "2030-06-01T12:00:00Z")
    assert_equal({ "scheduled_at" => "2030-06-01T12:00:00Z" }, last_body)
  end

  def test_send_test_goes_to_the_test_route_not_the_audience
    result = @mailtea.posts.send_test("post_1", recipients: ["you@example.com"],
                                                from: "Acme <hello@acme.com>")

    assert_request "POST", "/v1/posts/post_1/test"
    assert_equal({ "recipients" => ["you@example.com"], "from" => "Acme <hello@acme.com>" },
                 last_body)
    assert_equal ["you@example.com"], result["sent_to"]
  end
end

class TemplatesTest < MailteaTest
  def test_render_does_not_create_anything
    rendered = @mailtea.templates.render(spec: { "blocks" => [] }, variables: { "name" => "Ada" })

    assert_request "POST", "/v1/templates/render"
    assert_equal "<p>Rendered</p>", rendered["html"]
  end

  def test_create_list_get_update_delete
    created = @mailtea.templates.create(publication_id: "pub_1", name: "Receipt",
                                        html: "<p>Hi</p>")
    assert_request "POST", "/v1/templates"
    assert_equal "tpl_1", created["id"]

    @mailtea.templates.list(publication_id: "pub_1", limit: 10)
    assert_request "GET", "/v1/templates"

    @mailtea.templates.get("tpl_1", publication_id: "pub_1")
    assert_request "GET", "/v1/templates/tpl_1"

    @mailtea.templates.update("tpl_1", publication_id: "pub_1", subject: nil)
    assert_request "PATCH", "/v1/templates/tpl_1"
    assert_equal "pub_1", last_query["publication_id"]
    assert last_body.key?("subject"), "an explicit nil clears the field"

    @mailtea.templates.delete("tpl_1", publication_id: "pub_1")
    assert_request "DELETE", "/v1/templates/tpl_1"
  end

  def test_publish_unpublish_and_duplicate
    published = @mailtea.templates.publish("tpl_1", publication_id: "pub_1")
    assert_request "POST", "/v1/templates/tpl_1/publish"
    assert_equal "pub_1", last_query["publication_id"]
    assert_equal "published", published["status"]

    @mailtea.templates.unpublish("tpl_1", publication_id: "pub_1")
    assert_request "POST", "/v1/templates/tpl_1/unpublish"

    duplicated = @mailtea.templates.duplicate("tpl_1", publication_id: "pub_1")
    assert_request "POST", "/v1/templates/tpl_1/duplicate"
    assert_equal "tpl_copy", duplicated["id"]
  end

  def test_versions_and_restore
    versions = @mailtea.templates.versions("tpl_1", publication_id: "pub_1", limit: 5)
    assert_request "GET", "/v1/templates/tpl_1/versions"
    assert_equal 2, versions["data"].first["version"]

    restored = @mailtea.templates.restore_version("tpl_1", 1, publication_id: "pub_1")
    assert_request "POST", "/v1/templates/tpl_1/versions/1/restore"
    assert_equal 1, restored["restored_from_version"]
    # A restore is a content write, so it drops the template back to draft.
    assert_equal true, restored["unpublished"]
  end
end

class AssetsTest < MailteaTest
  PNG = "\x89PNG\r\n\x1A\n\x00binary".b

  def test_upload_base64_encodes_raw_bytes
    asset = @mailtea.assets.upload(publication_id: "pub_1", content: PNG,
                                   content_type: "image/png", filename: "hero.png")

    assert_request "POST", "/v1/assets"
    assert_equal [PNG].pack("m0"), last_body["content"]
    assert_equal "hero.png", last_body["filename"]
    assert_equal "https://cdn.example/ast_1.png", asset["url"]
  end

  def test_upload_leaves_an_already_encoded_string_alone
    encoded = [PNG].pack("m0")
    @mailtea.assets.upload(publication_id: "pub_1", content: encoded,
                           content_type: "image/png", filename: "hero.png")

    assert_equal encoded, last_body["content"]
  end

  def test_list_and_delete
    @mailtea.assets.list(publication_id: "pub_1", search: "hero")
    assert_request "GET", "/v1/assets"
    assert_equal "hero", last_query["search"]

    @mailtea.assets.delete("ast_1", publication_id: "pub_1")
    assert_request "DELETE", "/v1/assets/ast_1"
  end
end
