# Changelog

All notable changes to the `mailtea` Ruby gem are documented here.

## 0.3.0 (2026-09-10)

- Added: `mailtea.domains.update(id, tracking_subdomain: nil)` removes a
  tracking subdomain. The domain's links go back to being served from the
  Mailtea host. Links in mail you have already sent point at the old hostname
  and stop resolving — there is no way to reinstate them. Only the query string
  drops nils, so the removal travels in the body as an explicit null; leaving
  the key out and passing nil are different requests. An empty string is
  neither: it is refused with `tracking_subdomain_invalid`.
- Changed: the `MX` row in `records` now reports what the last verify found,
  instead of reading `pending` on every request but the verify itself. A domain
  nobody has verified reads `not_started`.

## 0.2.0 (2026-09-03)

- Added: the domain claims resource — `mailtea.domains.claims.create`, `.get`,
  `.verify` and `.cancel`. When adding a domain is refused because the host is
  connected to another publication, publish one TXT record to prove you control
  its DNS and the domain moves to you.
- Documented: domains take `region` (fixed at creation), `tls` and
  `tracking_subdomain` on create, and the list filters on `region` and `status`.
  This SDK forwards whatever parameters you pass, so these worked already — this
  release is where they are stated and covered by tests.

## 0.1.0 (2026-08-27)

First release. A thin, zero-dependency wrapper over the
[Mailtea REST API](https://docs.mailtea.app/docs/api-reference), built on
`net/http` and `json` from the standard library. Ruby 3.0+.

### Added

- **`Mailtea::Client`** — reads `MAILTEA_API_KEY` and the optional
  `MAILTEA_API_BASE_URL`, or takes both explicitly. The HTTP transport is
  injectable, so tests need no network and an app can route requests through its
  own instrumented stack.

- **Transactional email.** `emails.send`, `batch`, `get`, `list`, `analytics`,
  `update`, `reschedule` and `cancel` — plus `emails.inbound` for received mail
  (`list`, `get`, `reply`, and `attachments.list` / `attachments.get`).
  `emails.get` adds a `status` alias of the wire's `last_event`. The API caps a
  message at 50 recipients combined across `to`, `cc` and `bcc`.

- **Audience.** `contacts` (`create`/`upsert`, `list`, `get`, `update`,
  `delete`), `segments`, `topics`, `senders`, `suppressions` (including
  `export`, which returns raw CSV text), and `contact_properties`.

- **Content.** `posts` (`create`, `send`, `send_test`, `list`, `get`, `update`,
  `delete`), `templates` (including `render`, `publish`/`unpublish`, `versions`,
  `restore_version` and `duplicate`), and `assets` for the publication's image
  library — raw bytes are base64-encoded for you.

- **Platform.** `domains` (+ `domains.tracking`), `webhooks`, `api_keys`,
  `automations`, `automation_runs`, `events` and `event_definitions`.

- **`Mailtea.verify_webhook_signature` / `Mailtea.sign_webhook`** — Standard
  Webhooks verification with replay protection and a constant-time compare,
  checked in the test suite against signatures produced by the platform's own
  TypeScript signer.

- **`Mailtea::Error`** on every failure, carrying `status` (0 for a client-side
  fault such as an unreachable API), `message`, `code`, `details` and
  `request_id`.
