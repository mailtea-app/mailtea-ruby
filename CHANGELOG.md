# Changelog

All notable changes to the `mailtea` Ruby gem are documented here.

## 0.6.0 (2026-09-29)

- Docs: template history now records the sender. Each entry from the template
  versions call carries `from`, `reply_to` and `sender_recorded`, an update
  that changes only the From or Reply-To records a version (or folds into the
  open one, like any edit), and restoring a version brings its From and
  Reply-To back with the design. A version with `sender_recorded` false was
  recorded before this change and leaves the current From and Reply-To alone
  when restored. The behaviour comes from the API and reaches every SDK
  version on deploy; only the doc comments change here.

## 0.5.0 (2026-09-28)

- Breaking: `Posts#create` with `template_id` now HTML-escapes the `variables`
  you pass, the same as every other send. HTML passed in a `{{key}}` value now
  arrives as visible text, and a value you escaped yourself arrives
  double-escaped. Put `{{{key}}}` in the template where a value is meant to be
  raw HTML. Variables are now filled in both the `{{key}}` and Visual Email
  Designer `{key}` forms. A declared variable you do not pass stays in the
  post with its `fallback_value`, so the broadcast gives each recipient their
  own value or that fallback, and undeclared tokens like
  `{{contact.first_name}}` are left for the broadcast too. The post keeps the
  template's published page style, is wrapped in that page, and has its
  show-if blocks decided per recipient when it is sent. Before, only the
  variables you passed were replaced, raw, and only in `{{key}}` form. It uses
  the template's published version; Mailtea Studio's "Use template" starts
  from the latest saved design instead.
- Changed: `Templates#update` and `Templates#restore_version` no longer move a
  published template back to draft. The template keeps its published status,
  and automations and the API keep sending its published version until
  `Templates#publish` is called again. The template's `from` and `reply_to`
  are part of the published version too, so a new sender or reply-to address
  reaches sends only after the next publish. `Templates#unpublish` is now the
  only way to stop a published template sending, short of deleting it, and it
  drops the stored published version so the next publish starts from the
  current content.
- Added: `has_unpublished_versions` on every returned template hash. True only
  when the template is published and its saved content (From, Reply-To and the style profile
  included) differs from the published version.
- Added: `is_published` on each template version entry: true for the one entry
  automations and the API are sending now. `is_current` is now described as
  what it is: the entry that matches the working copy (the saved design being
  edited), not necessarily what is sending. `is_published` is false on every
  entry of a draft, and on a template published before the field existed until
  it is published again.
- Changed: the `unpublished` key on the update and restore replies is kept for
  compatibility and is now always `false`. Check `has_unpublished_versions`
  (or the reply's `message`) instead.
- Changed (API behavior): a template variable's `fallback_value` can no longer
  contain `{` or `}`. Creating a template with one, or changing a fallback
  to one on update, is a 400 ("Fallbacks can't contain { or }."). A value
  the template already stores is accepted unchanged, so a template saved
  before the rule keeps saving. Inline chip fallbacks such as
  `{first_name|Mom & Pop}` now render as written instead of double-escaped.
- Changed (API behavior): saving an active automation is refused only when the
  edit adds an error the live version does not already have. The 422
  `active_graph_invalid` reply's `issues` lists just those new problems.
  Before, any error refused the save, even one the live version already had.
  Starting refuses every error as before, except an `unknown_step_ref` at a
  `config.*` path or a trigger `missing_branch` that the version the
  automation last ran on already had, so pausing and starting an unchanged
  automation keeps working. Issues the last live version already had come back
  with `pre_existing: true`.
- Added (API behavior): issue objects carry `field`, what a rule reads (the
  rule's `field`, or the path in a `{"var": ...}` value, e.g.
  `steps.welcome.opened`) when the issue is about one.
- Changed (API behavior): two issues are the same problem when their code and
  step match, and their `field` or, when there is none, their `path`. Moving
  a rule, by removing a rule beside it or putting it in a group, no longer
  makes a problem the live version already had look new. An error is
  `pre_existing` only if the live version had an error there, not a warning.
- Changed (API behavior): `validate_only` on an active automation answers the
  way the save would. A trigger change is a 422 `trigger_locked_while_active`,
  a change that adds a problem is a 422 `active_graph_invalid` listing only
  the new problems, and otherwise issues come back with `pre_existing` marked
  against the version live now. Before, it returned every issue unmarked.
- Changed (API behavior): changing the trigger (its type or key) of an active
  automation is now refused with 422 `trigger_locked_while_active`. Pause it
  first; draft and paused automations can still change their trigger. Before,
  the change was accepted.
- Added (API behavior): new validation rules. A trigger with nothing after it
  is a `missing_branch` error at `branches.next`. A rule or `{"var": ...}`
  value that reads `steps.<key>.*` for a step that isn't in the automation is
  an `unknown_step_ref` error at that `config.*` path, or a warning when the
  `{"var": ...}` has a `default`. A rule or value that reads
  `event.properties.*` when the automation does not start from an app event is
  the new warning `event_field_without_event_trigger`.

## 0.4.0 (2026-09-15)

- Added: test mode. `mailtea.api_keys.create(name: "CI", mode: "test")` mints a
  test key (prefixed `mt_test_`) whose sends are validated, recorded and
  webhook-emitting but never delivered, so CI can run against production Mailtea
  with your real code and your real webhook handler. A test key is **not** a
  data sandbox — it reads and writes your real contacts, templates, senders and
  webhooks. Only delivery is simulated.
- Added: `mailtea.emails.list(mode: "test")` reads test-mode mail, and every
  email carries `mode`. There is no mixed view: a test key reads only test
  emails and a live key only live ones.
- Reserved recipients on `test.mailtea.email` force an outcome: `delivered@`,
  `bounced@`, `complained@`, `delayed@`, `failed@`. The first `to` recipient
  decides; anything else is delivered.

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
