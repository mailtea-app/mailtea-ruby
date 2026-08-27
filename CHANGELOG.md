# Changelog

All notable changes to the `mailtea` Ruby gem are documented here.

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
