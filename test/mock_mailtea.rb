# frozen_string_literal: true

# A tiny stand-in for the Mailtea API, so the tests run with no credentials and
# no network. It records every request it receives, which is what the assertions
# read.
#
# Ported from examples/.shared/node/mock-mailtea.mjs in the Mailtea monorepo and
# widened to every endpoint this SDK calls. WEBrick left Ruby's default gems in
# 3.0, so this uses TCPServer from the standard library rather than adding a gem
# just to run the tests.

require "json"
require "socket"
require "uri"

class MockMailtea
  EMAIL_ID = "txemail_00000000000000000000000000000000"

  Request = Struct.new(:method, :path, :pathname, :query, :authorization, :headers, :body,
                       keyword_init: true) do
    # "POST /v1/emails" — how most assertions want to read a request.
    def route
      "#{method} #{pathname}"
    end
  end

  attr_reader :url

  def initialize
    @server = TCPServer.new("127.0.0.1", 0)
    @url = "http://127.0.0.1:#{@server.addr[1]}"
    @requests = []
    @mutex = Mutex.new
    @thread = Thread.new { accept_loop }
  end

  def requests
    @mutex.synchronize { @requests.dup }
  end

  # The most recent request, which is what most assertions want.
  def last
    requests.last
  end

  def routes
    requests.map(&:route)
  end

  def close
    @server.close
    @thread.kill
  end

  private

  def accept_loop
    loop do
      socket = @server.accept
      Thread.new(socket) { |connection| handle(connection) }
    end
  rescue IOError, Errno::EBADF
    nil # the server was closed
  end

  def handle(socket)
    method, target = socket.gets.to_s.split(" ")

    headers = {}
    while (line = socket.gets) && line != "\r\n"
      key, value = line.split(":", 2)
      headers[key.to_s.strip.downcase] = value.to_s.strip
    end

    length = headers["content-length"].to_i
    raw = length.positive? ? socket.read(length) : nil
    body = if raw.nil?
             nil
           else
             begin
               JSON.parse(raw)
             rescue JSON::ParserError
               raw
             end
           end

    uri = URI.parse(target.to_s)
    request = Request.new(
      method: method,
      path: target,
      pathname: uri.path,
      query: uri.query ? URI.decode_www_form(uri.query).to_h : {},
      authorization: headers["authorization"],
      headers: headers,
      body: body
    )
    @mutex.synchronize { @requests << request }

    status, payload, content_type = route(request)
    respond(socket, status, payload, content_type || "application/json")
  rescue StandardError => e
    # A mock that dies silently makes the client look broken; say so instead.
    respond(socket, 500, { error: "mock failure: #{e.class}: #{e.message}" }, "application/json")
  ensure
    socket.close
  end

  # Ordered longest-first where routes overlap: /v1/emails/batch has to win over
  # /v1/emails/:id, or the tests pass against the wrong handler.
  def route(request)
    # Auth is checked first, the same way the real API does it — a client that
    # forgets the key should fail its test, not silently "send".
    return [401, { error: "Unauthorized" }] unless request.authorization.to_s.start_with?("Bearer ")

    verb = request.method
    path = request.pathname
    body = request.body

    case [verb, path]
    in ["POST", "/v1/emails"] then [200, { id: EMAIL_ID }]
    in ["GET", "/v1/emails"] then [200, list_of]
    in ["POST", "/v1/emails/batch"]
      items = body.is_a?(Array) ? body : []
      [200, { data: items.each_index.map { |i| { id: "txemail_#{i.to_s.rjust(32, "0")}" } } }]
    in ["GET", "/v1/emails/analytics"]
      [200, { object: "email_analytics", total: 1, delivered: 1, from_date: "2026-01-01T00:00:00.000Z" }]
    in ["GET", "/v1/emails/inbound"] then [200, list_of]
    in ["POST", "/v1/contacts"] then [200, { id: "con_1", object: "contact" }]
    in ["GET", "/v1/contacts"] then [200, list_of]
    in ["POST", "/v1/segments"] then [200, { id: "seg_1", object: "segment" }]
    in ["GET", "/v1/segments"] then [200, list_of]
    in ["POST", "/v1/topics"] then [200, { id: "top_1", name: body&.dig("name") || "Topic" }]
    in ["GET", "/v1/topics"] then [200, list_of]
    in ["POST", "/v1/posts"] then [200, { id: "post_1" }]
    in ["GET", "/v1/posts"] then [200, { object: "list", data: [], total: 0 }]
    in ["POST", "/v1/senders"] then [200, { id: "snd_1", object: "sender" }]
    in ["GET", "/v1/senders"] then [200, list_of]
    in ["POST", "/v1/assets"] then [200, { id: "ast_1", url: "https://cdn.example/ast_1.png" }]
    in ["GET", "/v1/assets"] then [200, list_of]
    in ["GET", "/v1/suppressions/export"]
      [200, "email,reason,source,created_at\nblocked@acme.com,bounce,ses,2026-01-01T00:00:00.000Z\n", "text/csv"]
    in ["GET", "/v1/suppressions"] then [200, list_of]
    in ["POST", "/v1/suppressions"] then [200, { added: (body&.dig("emails") || []).length }]
    in ["DELETE", "/v1/suppressions"] then [200, { removed: (body&.dig("emails") || []).length }]
    in ["POST", "/v1/templates/render"] then [200, { html: "<p>Rendered</p>", text: "Rendered" }]
    in ["POST", "/v1/templates"] then [200, { id: "tpl_1", object: "template" }]
    in ["GET", "/v1/templates"] then [200, list_of]
    in ["POST", "/v1/domains/claim"] then [200, domain_claim("clm_1")]
    in ["POST", "/v1/domains"] then [200, { id: "dom_1", records: [] }]
    in ["GET", "/v1/domains"] then [200, list_of]
    in ["POST", "/v1/webhooks/endpoints"] then [200, { id: "whe_1", signing_secret: "whsec_dGVzdA" }]
    in ["GET", "/v1/webhooks/endpoints"] then [200, list_of]
    in ["POST", "/v1/contact-properties"] then [200, { id: "cpr_1", key: body&.dig("key") }]
    in ["GET", "/v1/contact-properties"] then [200, list_of]
    in ["POST", "/v1/api-keys"] then [200, { id: "key_1", token: "mt_pat_returned_once" }]
    in ["GET", "/v1/api-keys"] then [200, list_of]
    in ["POST", "/v1/automations/validate"]
      [200, { object: "automation_validation", valid: true, issues: [] }]
    in ["POST", "/v1/automations"] then [200, { id: "aut_1", status: "draft" }]
    in ["GET", "/v1/automations"] then [200, list_of]
    in ["POST", "/v1/events"] then [202, { id: "evt_1", enrolled_automations: 0, resumed_runs: 0 }]
    in ["GET", "/v1/events"] then [200, list_of]
    in ["POST", "/v1/event-definitions"] then [200, { id: "evd_1", name: body&.dig("name") }]
    in ["GET", "/v1/event-definitions"] then [200, list_of]
    else parameterized(verb, path)
    end
  end

  # Routes with an id in them, matched by shape.
  def parameterized(verb, path)
    segments = path.split("/").reject(&:empty?) # ["v1", "emails", "txemail_1"]
    id = segments[2]
    tail = segments[3..] || []

    case segments[1]
    when "emails" then emails(verb, id, tail)
    when "contacts" then crud(verb, "contact", id)
    when "segments" then crud(verb, "segment", id)
    when "topics" then crud(verb, "topic", id)
    when "posts" then posts(verb, id, tail)
    when "senders" then crud(verb, "sender", id)
    when "assets" then crud(verb, "asset", id)
    when "templates" then templates(verb, id, tail)
    when "domains" then domains(verb, id, tail)
    when "webhooks" then crud(verb, "webhook_endpoint", segments[3])
    when "contact-properties" then crud(verb, "contact_property", id)
    when "api-keys" then crud(verb, "api_key", id)
    when "automations" then automations(verb, id, tail)
    when "event-definitions" then crud(verb, "event_definition", id)
    else [404, { error: "Not Found", path: path }]
    end
  end

  def emails(verb, id, tail)
    return inbound(verb, tail) if id == "inbound"
    return [200, { object: "email", id: id, last_event: "delivered", subject: "Mock email" }] if verb == "GET" && tail.empty?
    return [200, { object: "email", id: id, scheduled_at: "2030-06-01T12:00:00.000Z" }] if verb == "PATCH" && tail.empty?
    # Cancel is POST /v1/emails/:id/cancel. There is no DELETE on emails — the
    # real API does not define one (apps/api/src/email-rest.ts).
    return [200, { object: "email", id: id, last_event: "canceled" }] if verb == "POST" && tail == ["cancel"]

    [404, { error: "Not Found" }]
  end

  # /v1/emails/inbound/:id[/reply|/attachments[/:attachment_id]]
  def inbound(verb, tail)
    id = tail[0]
    case [verb, tail[1]]
    in ["GET", nil] then [200, { object: "inbound_email", id: id, subject: "Received" }]
    in ["POST", "reply"] then [200, { id: EMAIL_ID, status: "queued" }]
    in ["GET", "attachments"]
      if tail[2]
        [200, { object: "inbound_attachment", id: tail[2], download_url: "https://cdn.example/a" }]
      else
        [200, { object: "list", data: [{ id: "att_1", download_url: "https://cdn.example/a" }] }]
      end
    else [404, { error: "Not Found" }]
    end
  end

  def posts(verb, id, tail)
    case [verb, tail[0]]
    in ["GET", nil] then [200, { object: "post", id: id, subject: "Mock post" }]
    in ["PATCH", nil] then [200, { object: "post", id: id }]
    in ["DELETE", nil] then [200, { object: "post", id: id, deleted: true }]
    in ["POST", "send"] then [200, { id: id, status: "sending" }]
    in ["POST", "test"] then [200, { sent_to: ["you@example.com"], failed_to: [] }]
    else [404, { error: "Not Found" }]
    end
  end

  def templates(verb, id, tail)
    case [verb, tail[0]]
    in ["GET", nil] then [200, { object: "template", id: id }]
    in ["PATCH", nil] then [200, { object: "template", id: id }]
    in ["DELETE", nil] then [200, { object: "template", id: id, deleted: true }]
    in ["POST", "publish"] then [200, { object: "template", id: id, status: "published" }]
    in ["POST", "unpublish"] then [200, { object: "template", id: id, status: "draft" }]
    in ["POST", "duplicate"] then [200, { object: "template", id: "tpl_copy" }]
    in ["GET", "versions"] then [200, { object: "list", data: [{ version: 2, is_current: true }] }]
    in ["POST", "versions"]
      [200, { restored: true, restored_from_version: tail[1].to_i, unpublished: true }]
    else [404, { error: "Not Found" }]
    end
  end

  def domains(verb, id, tail)
    # /v1/domains/claims/:id sits a level deeper than /v1/domains/:id, so the
    # claim id is tail[0], not the id the caller's path handed us.
    return claims(verb, tail[0], tail[1]) if id == "claims"

    case [verb, tail[0]]
    in ["GET", nil] then [200, { object: "domain", id: id, status: "pending", records: [] }]
    in ["PATCH", nil] then [200, { object: "domain", id: id }]
    in ["DELETE", nil] then [200, { object: "domain", id: id, deleted: true }]
    in ["POST", "verify"] then [200, { object: "domain", id: id, status: "verified" }]
    in ["POST", "tracking-domains"]
      tail[1] ? [200, { id: tail[1], status: "verified" }] : [200, { id: "trk_1", records: [] }]
    in ["GET", "tracking-domains"] then [200, list_of]
    in ["DELETE", "tracking-domains"] then [200, { id: tail[1], deleted: true }]
    else [404, { error: "Not Found" }]
    end
  end

  def claims(verb, id, tail)
    case [verb, tail]
    in ["GET", nil] then [200, domain_claim(id)]
    in ["DELETE", nil] then [200, { object: "domain_claim", id: id, deleted: true }]
    # Verify answers with the claim AND the domain it produced, so the claimant
    # can publish its DNS without a second request.
    in ["POST", "verify"]
      [200, domain_claim(id, "completed", "dom_2").merge(
        domain: { object: "domain", id: "dom_2", status: "pending", records: [] }
      )]
    else [404, { error: "Not Found" }]
    end
  end

  # A domain claim in the shape apps/api/src/domain-claims-rest.ts returns: the
  # TXT record to publish lives in +records+, never in a bare +txt+ field.
  def domain_claim(id, status = "pending", domain_id = nil)
    completed = status == "completed"
    {
      object: "domain_claim",
      id: id,
      publication_id: "pub_1",
      name: "acme.com",
      region: "eu-west-1",
      status: status,
      records: [{ record: "Claim", type: "TXT", name: "_mailtea-claim.acme.com",
                  value: "mailtea-claim=#{id}",
                  status: completed ? "verified" : "pending" }],
      failure_reason: nil,
      domain_id: domain_id,
      created_at: "2026-09-01T00:00:00.000Z",
      expires_at: completed ? nil : "2026-09-08T00:00:00.000Z",
      completed_at: completed ? "2026-09-01T00:10:00.000Z" : nil
    }
  end

  def automations(verb, id, tail)
    case [verb, tail[0]]
    in ["GET", nil] then [200, { object: "automation", id: id, steps: [], issues: [] }]
    in ["PATCH", nil] then [200, { object: "automation", id: id }]
    in ["DELETE", nil] then [200, { object: "automation", id: id, deleted: true }]
    in ["POST", "activate"] then [200, { object: "automation", id: id, status: "active" }]
    in ["POST", "pause"] then [200, { object: "automation", id: id, status: "paused", canceled_runs: 0 }]
    in ["POST", "archive"] then [200, { object: "automation", id: id, status: "archived", canceled_runs: 3 }]
    in ["POST", "test"] then [202, { object: "automation_run", id: "run_1", is_test: true }]
    in ["GET", "metrics"] then [200, { object: "automation_metrics", excludes_test_runs: true, steps: [] }]
    in ["GET", "versions"]
      tail[1] ? [200, { version: tail[1].to_i, steps: [] }] : [200, list_of]
    in ["GET", "runs"]
      tail[1] ? [200, { object: "automation_run", id: tail[1], step_runs: [] }] : [200, list_of]
    in ["POST", "runs"] then [200, { object: "automation_run", id: tail[1], status: "canceled" }]
    else [404, { error: "Not Found" }]
    end
  end

  # The generic shapes: an object for GET/PATCH, a tombstone for DELETE.
  def crud(verb, object, id)
    case verb
    when "GET", "PATCH" then [200, { object: object, id: id }]
    when "DELETE" then [200, { object: object, id: id, deleted: true }]
    else [404, { error: "Not Found" }]
    end
  end

  def list_of(data = [])
    { object: "list", data: data, total: data.length, limit: 20, offset: 0, has_more: false }
  end

  def respond(socket, status, payload, content_type = "application/json")
    body = payload.is_a?(String) ? payload : JSON.generate(payload)
    socket.print("HTTP/1.1 #{status}\r\n")
    socket.print("Content-Type: #{content_type}\r\n")
    socket.print("Content-Length: #{body.bytesize}\r\n")
    socket.print("x-request-id: req_mock_1\r\n")
    socket.print("Connection: close\r\n\r\n")
    socket.print(body)
  end
end
