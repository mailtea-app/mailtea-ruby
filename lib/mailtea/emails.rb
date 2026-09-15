# frozen_string_literal: true

require_relative "resource"
require_relative "inbound"

module Mailtea
  # The +emails+ resource: transactional send, status, scheduling, and the
  # inbound sub-resource. Reach it at <tt>mailtea.emails</tt>.
  #
  # The documented fields are named keywords; anything else the API accepts can
  # be passed as an extra keyword or inside a leading wire-format Hash, and both
  # styles can be mixed:
  #
  #   mailtea.emails.send(from: "a@b.co", to: "c@d.co", subject: "Hi", html: "<p>Hi</p>")
  #   mailtea.emails.send({ "from" => "a@b.co", "to" => "c@d.co", "subject" => "Hi" })
  class Emails < Resource
    # Inbound (received) emails: list, get, reply, and attachments.
    attr_reader :inbound

    def initialize(request)
      super
      @inbound = InboundEmails.new(request)
    end

    # Send a transactional email. Provide +html+/+text+ OR a +template+.
    # Returns <tt>{ "id" => ... }</tt>.
    #
    # Set the From with exactly one of +from+ (a <tt>Name <email></tt> string) or
    # +sender_id+ (the id of a named, verified publication sender, which also
    # supplies its default +reply_to+).
    #
    # +to+, +cc+, +bcc+ and +reply_to+ each take a single address or an Array.
    # The API caps a message at **50 recipients combined** across +to+, +cc+ and
    # +bcc+.
    #
    # - +tags+ — an Array of <tt>{ name:, value: }</tt> for filtering and analytics.
    # - +headers+ — a Hash of extra custom email headers.
    # - +attachments+ — an Array of <tt>{ filename:, content: }</tt> where
    #   +content+ is base64. Add +content_type+ and a +content_id+ to embed an
    #   inline image referenced by <tt>cid:</tt> in the HTML; omit +content_id+
    #   for a regular file attachment.
    # - +scheduled_at+ — an ISO 8601 datetime to schedule the send.
    # - +tracking_open+ / +tracking_click+ — opt this message out of the open
    #   pixel or link rewriting. A sending domain with tracking off cannot be
    #   overridden from a send.
    #
    # This deliberately shadows Object#send on the resource object, because the
    # API's verb is "send" and reading <tt>mailtea.emails.send(...)</tt> matters
    # more than metaprogramming on a resource. Ruby's +__send__+ is untouched.
    def send(params = nil, to: UNSET, subject: UNSET, from: UNSET, sender_id: UNSET,
             html: UNSET, text: UNSET, template: UNSET, cc: UNSET, bcc: UNSET,
             reply_to: UNSET, tags: UNSET, headers: UNSET, attachments: UNSET,
             scheduled_at: UNSET, tracking_open: UNSET, tracking_click: UNSET, **rest)
      body = payload(
        params,
        { to: to, subject: subject, from: from, sender_id: sender_id, html: html,
          text: text, template: template, cc: cc, bcc: bcc, reply_to: reply_to,
          tags: tags, headers: headers, attachments: attachments,
          scheduled_at: scheduled_at, tracking_open: tracking_open,
          tracking_click: tracking_click },
        rest
      )
      request("POST", "/v1/emails", body)
    end

    # Send up to 100 emails in one request. Takes an Array of send payloads and
    # returns <tt>{ "data" => [{ "id" => ... }] }</tt>.
    #
    # The array goes out as the request body verbatim, so each item takes the
    # same fields as #send except +scheduled_at+ and +attachments+.
    def batch(emails)
      unless emails.is_a?(Array)
        raise Error.new(
          "emails.batch takes an Array of email payloads, got #{emails.class}.",
          code: "invalid_batch"
        )
      end

      request("POST", "/v1/emails/batch", emails.map { |email| payload(email) })
    end

    # Retrieve an email with its delivery status and tracking counters.
    #
    # Adds a friendly +status+ alias of the raw +last_event+ wire field:
    # "queued", "scheduled", "sent", "delivered", "bounced", "complained",
    # "failed", "delivery_delayed", "suppressed" or "canceled".
    def get(id)
      email = request("GET", "/v1/emails/" + escape(id))
      email["status"] = email["last_event"] if email.is_a?(Hash) && email["status"].nil?
      email
    end

    # List emails (most recent first). Optional filters: +status+, +mode+,
    # +tag_name+, +tag_value+, +search+ (substring match on
    # recipient/sender/subject), +from_date+, +to_date+, +limit+, +offset+.
    #
    # +mode+ is "live" or "test" — there is no mixed view. A test key reads only
    # test mail and a live key only live mail, so this filter matters to a
    # session-backed credential; asking for the mode your key is not in is an
    # error rather than an empty list. Every returned email carries its own
    # +mode+.
    #
    # +from_date+ is clamped to the plan's analytics retention window — 30 days
    # on most plans, 90 on Scale and Enterprise. A value reaching further back
    # returns data from the start of that window rather than an error, and
    # omitting it returns the window rather than all time.
    def list(params = nil, **filters)
      request("GET", "/v1/emails" + query(payload(params, filters)))
    end

    # Aggregate transactional metrics over an optional date window: totals,
    # delivered/bounced/open/click counts, per-status counts, and rates.
    # Optional filters: +from_date+, +to_date+ (ISO 8601).
    #
    # +from_date+ is clamped the same way as #list, and the +from_date+ in the
    # response reports the window actually used.
    def analytics(params = nil, **filters)
      request("GET", "/v1/emails/analytics" + query(payload(params, filters)))
    end

    # Update a scheduled email (currently only +scheduled_at+).
    def update(id, params = nil, scheduled_at: UNSET, **rest)
      body = payload(params, { scheduled_at: scheduled_at }, rest)
      request("PATCH", "/v1/emails/" + escape(id), body)
    end

    # Convenience wrapper over #update for the reschedule case.
    def reschedule(id, scheduled_at)
      update(id, scheduled_at: scheduled_at)
    end

    # Cancel a scheduled email before it sends.
    #
    # Only a message still sitting at +last_event+ "scheduled" can be cancelled:
    # a send with no +scheduled_at+ is already on its way and answers 422, and so
    # does a scheduled one once its time has passed.
    def cancel(id)
      request("POST", "/v1/emails/" + escape(id) + "/cancel")
    end
  end
end
