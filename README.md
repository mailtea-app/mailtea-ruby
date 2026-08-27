# mailtea-ruby

The official Ruby SDK for [Mailtea](https://mailtea.app) — a thin, typed wrapper
over the [REST API](https://docs.mailtea.app/docs/api-reference). Ruby 3.0+, no
runtime dependencies.

## Install

```bash
gem install mailtea
```

Or in a `Gemfile`:

```ruby
gem "mailtea", "~> 0.1"
```

## Usage

```ruby
require "mailtea"

mailtea = Mailtea::Client.new # reads MAILTEA_API_KEY

sent = mailtea.emails.send(
  from: "you@yourdomain.com",
  to: "recipient@example.com",
  subject: "Hello from Mailtea",
  html: "<p>Your first email, sent with <strong>Mailtea</strong>.</p>"
)
puts sent["id"]

email = mailtea.emails.get(sent["id"])
puts email["status"] # "queued" right after a send; delivery is asynchronous
```

Responses are the wire JSON as a Hash that also takes Symbol keys, so
`email["id"]` and `email[:id]` are the same lookup. Keys are never renamed: what
the API reference documents is what you index.

The documented fields of a request are named keyword arguments; anything else
the API accepts can be passed as an extra keyword, or as a leading wire-format
Hash, and both styles can be mixed:

```ruby
mailtea.emails.send({ "from" => "you@yourdomain.com", "subject" => "Hello" },
                    to: "recipient@example.com",
                    html: "<p>Hi</p>")
```

Named keywords cover `emails.send` / `batch` / `update`, `contacts.create` /
`update`, `posts.create` / `send` / `send_test`, `topics.create` and
`emails.inbound.reply`. Every other method takes the Hash-or-keywords form for
the whole payload — the API reference is the field list.

A keyword you do not pass is left out of the request; one you pass as `nil` is
sent as JSON `null`, which is how the API clears a nullable field:

```ruby
mailtea.segments.update(id, publication_id: pub)                      # leaves the filter alone
mailtea.segments.update(id, publication_id: pub, status_filter: nil)  # clears it
```

`emails.send` also takes `tags`, custom `headers`, `attachments` and
`scheduled_at`. Attachments carry base64 `content`; set a `content_id` (plus
`content_type`) to embed an inline image referenced by `cid:` in the HTML:

```ruby
mailtea.emails.send(
  from: "you@yourdomain.com",
  to: "recipient@example.com",
  subject: "Your receipt",
  html: '<p>Thanks!</p><img src="cid:logo" />',
  tags: [{ name: "category", value: "receipt" }],
  attachments: [
    { filename: "receipt.pdf", content: pdf_base64 },
    { filename: "logo.png", content: logo_base64,
      content_type: "image/png", content_id: "logo" } # inline
  ]
)
```

`to`, `cc`, `bcc` and `reply_to` each take a single address or an Array. The API
caps a message at **50 recipients combined** across `to` + `cc` + `bcc`.

## Configuration

| What | How |
|---|---|
| API key | `Mailtea::Client.new("mt_pat_…")`, or the `MAILTEA_API_KEY` environment variable |
| Base URL | `Mailtea::Client.new(key, base_url: "…")`, or `MAILTEA_API_BASE_URL`. Defaults to `https://api.mailtea.app` |
| HTTP transport | `Mailtea::Client.new(key, transport: my_transport)` |

```bash
export MAILTEA_API_KEY="mt_pat_xxxxxxxx"
export MAILTEA_API_BASE_URL="http://127.0.0.1:7787"  # self-hosted or local only
```

A transport is anything that responds to
`call(method, url, headers, body) -> Mailtea::HttpResponse`. Pass one to record
requests in tests, route through a proxy, or reuse a connection pool —
everything above the wire stays the same:

```ruby
recorder = lambda do |method, url, headers, body|
  puts "#{method} #{url}"
  Mailtea::Transport.call(method, url, headers, body)
end

mailtea = Mailtea::Client.new(ENV["MAILTEA_API_KEY"], transport: recorder)
```

## API

| Method | Description |
| --- | --- |
| `emails.send(params)` | Send a transactional email → `{ "id" => … }` |
| `emails.batch(emails)` | Send up to 100 emails → `{ "data" => [{ "id" => … }] }` |
| `emails.get(id)` | Retrieve an email and its delivery status |
| `emails.list(params = nil)` | List emails → `{ "data", "total", "limit", "offset", "has_more" }` |
| `emails.update(id, params)` | Reschedule a scheduled email |
| `emails.reschedule(id, scheduled_at)` | Convenience wrapper over `update` |
| `emails.cancel(id)` | Cancel a scheduled email (`POST /v1/emails/:id/cancel`) |
| `emails.analytics(params = nil)` | Aggregate transactional metrics over an optional date window |
| `emails.inbound.list(params = nil)` | List received emails in a publication (cursor-paginated) |
| `emails.inbound.get(id)` | Retrieve a received email with body, headers and attachments |
| `emails.inbound.reply(id, params)` | Reply to a received email (threads by construction) |
| `emails.inbound.attachments.list(id)` | List a received email's attachments (signed download URLs) |
| `emails.inbound.attachments.get(id, attachment_id)` | Retrieve one inbound attachment |
| `contacts.create / upsert / list / get / update / delete` | Manage audience contacts (`upsert` = `create`; the endpoint upserts) |
| `posts.create(params)` | Create a newsletter post (draft, or `send: true`) → `{ "id" => … }` |
| `posts.send(id, params = nil)` | Send a draft post to the audience, now or at `scheduled_at` |
| `posts.send_test(id, params)` | Send a `[TEST]` copy of a post → `{ "sent_to", "failed_to" }` |
| `posts.list / get / update / delete` | Manage posts (offset-paginated list) |
| `segments.create / list / get / update / delete` | Manage audience segments |
| `topics.create / list / get / update / delete` | Manage topic definitions (`visibility: "public"` → shown on the reader preference page) |
| `senders.create / list / get / update / delete` | Manage named From identities (`email` immutable) |
| `templates.create / list / get / update / publish / unpublish / duplicate / delete` | Manage reusable email templates |
| `templates.render(params)` | Render a spec to HTML without saving → `{ "html", "text" }` |
| `templates.versions(id, params = nil)` | List a template's design history, newest first (metadata only) |
| `templates.restore_version(id, version, params = nil)` | Put an older design back — a content write, so the template returns to **draft** |
| `assets.upload / list / delete` | The publication's image library (raw bytes are base64-encoded for you) |
| `suppressions.list / add / remove` | Manage the team-wide do-not-send list |
| `suppressions.export` | Export the whole suppression list as CSV (raw text) |
| `domains.create / list / get / verify / update / delete` | Manage sending domains (add, read DNS records, verify) |
| `domains.tracking.create / list / verify / delete` | Manage CNAME tracking sub-domains under a domain |
| `webhooks.create / list / get / update / delete` | Manage outbound event subscriptions |
| `contact_properties.create / list / update / delete` | Manage custom contact fields (team-scoped) |
| `api_keys.create / list / revoke` | Manage API keys (`settings:write`) |
| `automations.create / list / get / update / delete` | Manage automation graphs (`steps` + optional `connections`) |
| `automations.validate(params)` | Dry-run a graph → `{ "valid", "issues" }` (no automation needed) |
| `automations.activate / pause / archive` | Lifecycle (`cancel_runs` defaults **false** on pause, **true** on archive) |
| `automations.versions(id, …)` / `automations.version(id, version, …)` | List stored versions; retrieve one with its graph |
| `automations.metrics(id, params = nil)` | Per-step funnel counts and branch splits (test runs excluded) |
| `automations.test(id, params)` | One test run against a real contact — **sends real, billed email** |
| `automation_runs.list / get / cancel` | Inspect and cancel runs (a run pins the version it started on) |
| `events.send(params)` | Record a custom event → `{ "enrolled_automations", "resumed_runs" }` |
| `events.list(params)` | List recorded events (cursor-paginated) |
| `event_definitions.create / list / get / update / delete` | Manage the event catalog (`name` immutable) |

Audience, content and platform resources are scoped to a publication — pass
`publication_id`. `suppressions` and `contact_properties` are team-scoped and
take none.

`emails.send`, `posts.send` and `events.send` deliberately shadow `Object#send`
on their resource object, because the API's verb is "send". Ruby's `__send__`
is untouched, so metaprogramming still works.

## Webhooks

Mailtea signs every outbound webhook with
[Standard Webhooks](https://www.standardwebhooks.com/).
`Mailtea.verify_webhook_signature` checks the signature and rejects replays.
Pass the **raw** request body (not re-serialized JSON) and the endpoint's
`whsec_…` signing secret:

```ruby
ok = Mailtea.verify_webhook_signature(
  signing_secret,                        # whsec_… from webhooks.create
  request.headers["webhook-id"],
  request.headers["webhook-timestamp"],
  request.raw_post,                      # exact bytes received
  request.headers["webhook-signature"]
)
head :unauthorized unless ok
```

The timestamp window defaults to 5 minutes each way and both it and the clock
are injectable: `tolerance_seconds:` and `now:`.
`Mailtea.sign_webhook(secret, msg_id, timestamp, payload)` produces the same
header, which is how you fake a delivery in your own tests.

## Errors

Every failure raises `Mailtea::Error` — an API error and a dropped connection
alike, so one `rescue` covers the send path:

```ruby
begin
  mailtea.emails.send(from: from, to: to, subject: "Hi", html: "<p>Hi</p>")
rescue Mailtea::Error => e
  warn e.message   # the API's own message, e.g. "Domain not verified"
  e.status         # 422 — or 0 when the request never left the process
  e.code           # machine-readable code, when the API sends one
  e.details        # validation issues, when the API sends them
  e.request_id     # the x-request-id header; quote it in support tickets
end
```

`status` is `0` for a client-side fault: a missing API key, an unreachable host,
a timeout. Branch on `code` rather than the message — copy changes, codes do not.

## Local development

```bash
bundle install
bundle exec rake test
```

The tests run against a bundled mock API on an ephemeral port
(`test/mock_mailtea.rb`), so they need no credentials and make no network calls.

To run against a local Mailtea instead:

```bash
export MAILTEA_API_KEY="mt_pat_…"
export MAILTEA_API_BASE_URL="http://127.0.0.1:7787"
ruby -Ilib -e 'require "mailtea"; p Mailtea::Client.new.emails.list(limit: 1)'
```

## License

MIT. See [LICENSE](LICENSE).
