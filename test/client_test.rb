# frozen_string_literal: true

require_relative "test_helper"

# A transport that answers from a queue and records what it was asked for, so a
# response shape can be pinned without a socket. This is the same seam a caller
# uses to put the SDK behind their own HTTP stack.
class RecordingTransport
  attr_reader :calls

  def initialize(responses)
    @responses = responses.dup
    @calls = []
  end

  def call(method, url, headers, body)
    @calls << { method: method, url: url, headers: headers, body: body }
    spec = @responses.shift || {}
    Mailtea::HttpResponse.new(
      status: spec.fetch(:status, 200),
      headers: { "x-request-id" => "req_1" }.merge(spec.fetch(:headers, {})),
      body: spec.key?(:text) ? spec[:text] : JSON.generate(spec.fetch(:json, {}))
    )
  end
end

# Strips the Authorization header on its way out, to prove the API refuses an
# unauthenticated request rather than the SDK quietly succeeding.
class UnauthenticatedTransport
  def call(method, url, headers, body)
    Mailtea::Transport.call(method, url, headers.reject { |name, _| name == "Authorization" }, body)
  end
end

class ClientTest < MailteaTest
  def with_env(values)
    previous = values.keys.to_h { |key| [key, ENV.fetch(key, nil)] }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    previous.each { |key, value| ENV[key] = value }
  end

  def test_reads_the_key_and_base_url_from_the_environment
    with_env("MAILTEA_API_KEY" => "mt_pat_env", "MAILTEA_API_BASE_URL" => @mock.url) do
      Mailtea::Client.new.emails.get("txemail_1")
    end

    assert_equal "Bearer mt_pat_env", @mock.last.authorization
    assert_equal "GET /v1/emails/txemail_1", @mock.last.route
  end

  def test_an_explicit_key_and_base_url_beat_the_environment
    with_env("MAILTEA_API_KEY" => "mt_pat_env", "MAILTEA_API_BASE_URL" => "https://api.example.test") do
      Mailtea::Client.new("mt_pat_explicit", base_url: @mock.url).emails.get("txemail_1")
    end

    assert_equal "Bearer mt_pat_explicit", @mock.last.authorization
  end

  def test_defaults_to_the_public_api_and_strips_a_trailing_slash
    with_env("MAILTEA_API_KEY" => nil, "MAILTEA_API_BASE_URL" => nil) do
      assert_equal "https://api.mailtea.app", Mailtea::Client.new("mt_pat_x").base_url
    end

    assert_equal "http://127.0.0.1:1/v1", Mailtea::Client.new("k", base_url: "http://127.0.0.1:1/v1/").base_url
  end

  def test_refuses_to_start_without_a_key
    with_env("MAILTEA_API_KEY" => nil) do
      error = assert_raises(Mailtea::Error) { Mailtea::Client.new }
      assert_equal 0, error.status
      assert_equal "missing_api_key", error.code
      assert_raises(Mailtea::Error) { Mailtea::Client.new("") }
    end
  end

  def test_inspect_does_not_leak_the_key
    refute_includes @mailtea.inspect, API_KEY
    assert_includes @mailtea.inspect, @mock.url
  end

  def test_sends_the_versioned_user_agent_and_json_content_type
    @mailtea.emails.send(from: "a@b.co", to: "c@d.co", subject: "Hi", html: "<p>Hi</p>")

    assert_equal "mailtea-ruby/#{Mailtea::VERSION}", @mock.last.headers["user-agent"]
    assert_equal "application/json", @mock.last.headers["content-type"]
  end

  def test_a_get_carries_no_body_or_content_type
    @mailtea.emails.list

    assert_nil @mock.last.body
    assert_nil @mock.last.headers["content-type"]
  end

  def test_the_api_rejects_a_request_with_no_bearer_header
    client = Mailtea::Client.new("k", base_url: @mock.url, transport: UnauthenticatedTransport.new)
    error = assert_raises(Mailtea::Error) { client.emails.list }

    assert_equal 401, error.status
    assert_equal "Unauthorized", error.message
  end

  def test_a_non_2xx_response_raises_with_status_message_code_details_and_request_id
    transport = RecordingTransport.new([
      { status: 422, json: { error: "Domain not verified", code: "domain_not_verified",
                             details: [{ path: "from", message: "unverified" }] } }
    ])
    client = Mailtea::Client.new("k", base_url: "https://api.mailtea.app", transport: transport)

    error = assert_raises(Mailtea::Error) do
      client.emails.send(from: "a@b.co", to: "c@d.co", subject: "Hi")
    end

    assert_equal 422, error.status
    assert_equal "Domain not verified", error.message
    assert_equal "domain_not_verified", error.code
    assert_equal [{ "path" => "from", "message" => "unverified" }], error.details
    assert_equal "req_1", error.request_id
  end

  def test_a_non_json_error_body_keeps_the_status_line_message
    transport = RecordingTransport.new([{ status: 502, text: "<html>bad gateway</html>" }])
    client = Mailtea::Client.new("k", base_url: "https://api.mailtea.app", transport: transport)

    error = assert_raises(Mailtea::Error) { client.emails.list }

    assert_equal 502, error.status
    assert_equal "HTTP 502", error.message
    assert_nil error.code
  end

  def test_an_empty_or_204_body_returns_nil
    transport = RecordingTransport.new([{ status: 204, text: "" }, { status: 200, text: "" }])
    client = Mailtea::Client.new("k", base_url: "https://api.mailtea.app", transport: transport)

    assert_nil client.api_keys.revoke("key_1")
    assert_nil client.api_keys.revoke("key_2")
  end

  def test_an_unreachable_api_raises_the_same_error_class_with_status_zero
    dead = MockMailtea.new
    dead_url = dead.url
    dead.close

    client = Mailtea::Client.new("k", base_url: dead_url)
    error = assert_raises(Mailtea::Error) { client.emails.list }

    assert_equal 0, error.status
    assert_equal "connection_error", error.code
    assert_includes error.message, "Could not reach Mailtea at"
  end

  # Dropping the scheme off MAILTEA_API_BASE_URL is the easiest way to
  # misconfigure this client, and both spellings of the mistake used to escape
  # the one-rescue contract: Net::HTTP raised a bare ArgumentError ("not an HTTP
  # URI") for "api.mailtea.app", and "127.0.0.1:7787" arrived as an unhelpful
  # connection_error because a host:port parses as scheme:opaque.
  def test_a_base_url_with_no_scheme_is_a_typed_error_not_a_bare_argument_error
    ["api.mailtea.app", "127.0.0.1:7787", "localhost:7787", "//api.mailtea.app",
     "ftp://api.mailtea.app"].each do |base_url|
      client = Mailtea::Client.new("k", base_url: base_url)
      error = assert_raises(Mailtea::Error, "#{base_url.inspect} did not raise Mailtea::Error") do
        client.emails.list
      end

      assert_equal 0, error.status
      assert_equal "invalid_base_url", error.code
      assert_includes error.message, "http:// or https://"
      # The message names the base the caller set, not the path the SDK built.
      assert_includes error.message, base_url
      refute_includes error.message, "/v1/emails"
    end
  end

  def test_a_response_key_written_with_a_symbol_reads_back_with_either
    transport = RecordingTransport.new([{ json: { id: "txemail_1" } }])
    client = Mailtea::Client.new("k", base_url: "https://api.mailtea.app", transport: transport)

    email = client.emails.get("txemail_1")
    email[:note] = "written with a symbol"

    assert_equal "written with a symbol", email[:note]
    assert_equal "written with a symbol", email["note"]
    email.delete(:note)
    refute email.key?("note")
  end

  def test_responses_take_string_and_symbol_keys_and_dig
    transport = RecordingTransport.new([
      { json: { id: "txemail_1", tags: [{ name: "category", value: "receipt" }] } }
    ])
    client = Mailtea::Client.new("k", base_url: "https://api.mailtea.app", transport: transport)

    email = client.emails.get("txemail_1")

    assert_equal "txemail_1", email["id"]
    assert_equal "txemail_1", email[:id]
    assert_equal "receipt", email.dig(:tags, 0, :value)
    assert email.key?(:id)
    assert_equal "txemail_1", email.fetch(:id)
  end

  def test_an_injected_transport_receives_the_fully_built_request
    transport = RecordingTransport.new([{ json: { id: "txemail_1" } }])
    client = Mailtea::Client.new("mt_pat_injected", base_url: "https://api.example.test",
                                                   transport: transport)

    client.emails.send(from: "a@b.co", to: "c@d.co", subject: "Hi")

    call = transport.calls.first
    assert_equal "POST", call[:method]
    assert_equal "https://api.example.test/v1/emails", call[:url]
    assert_equal "Bearer mt_pat_injected", call[:headers]["Authorization"]
    assert_equal({ "from" => "a@b.co", "to" => "c@d.co", "subject" => "Hi" }, JSON.parse(call[:body]))
  end

  # The quickstart this repository publishes — README "Usage", and the same
  # shape lib/mailtea.rb's own header comment shows. It is a promise about this
  # interface, so it runs here rather than only being proofread.
  def test_the_documented_quickstart_snippet_works_verbatim
    with_env("MAILTEA_API_KEY" => "mt_pat_env", "MAILTEA_API_BASE_URL" => @mock.url) do
      mailtea = Mailtea::Client.new

      email = mailtea.emails.send(
        from: "you@yourdomain.com",
        to: "recipient@example.com",
        subject: "Hello from Mailtea",
        html: "<p>Your first email, sent via the API.</p>"
      )

      assert_equal MockMailtea::EMAIL_ID, email["id"]
    end

    assert_equal "POST /v1/emails", @mock.last.route
    assert_equal "Bearer mt_pat_env", @mock.last.authorization
    assert_equal(
      { "from" => "you@yourdomain.com", "to" => "recipient@example.com",
        "subject" => "Hello from Mailtea",
        "html" => "<p>Your first email, sent via the API.</p>" },
      last_body
    )
  end

  def test_a_path_id_is_escaped_rather_than_walking_to_another_route
    @mailtea.emails.get("../../v1/api-keys")

    assert_equal "/v1/emails/..%2F..%2Fv1%2Fapi-keys", @mock.last.pathname
  end
end
