# frozen_string_literal: true

require_relative "resource"

module Mailtea
  # The +posts+ resource (newsletter posts/issues). Reach it at
  # <tt>mailtea.posts</tt>.
  class Posts < Resource
    # Create a newsletter post (a draft by default). Seed it from a published
    # server template with +template_id+ + +variables+, or pass inline +html+.
    # +kind+ selects the post type ("newsletter" or "broadcast"). Set
    # <tt>send: true</tt> to deliver right after creating (or with
    # +scheduled_at+ to schedule) — that requires the +issues:send+ scope.
    #
    # Returns <tt>{ "id" => ... }</tt>.
    def create(params = nil, publication_id: UNSET, subject: UNSET, html: UNSET,
               text: UNSET, template_id: UNSET, variables: UNSET, from: UNSET,
               reply_to: UNSET, name: UNSET, kind: UNSET, send: UNSET,
               scheduled_at: UNSET, **rest)
      body = payload(
        params,
        { publication_id: publication_id, subject: subject, html: html, text: text,
          template_id: template_id, variables: variables, from: from,
          reply_to: reply_to, name: name, kind: kind, send: send,
          scheduled_at: scheduled_at },
        rest
      )
      request("POST", "/v1/posts", body)
    end

    # List posts (most recent first, offset-paginated). Takes +publication_id+
    # (required) plus optional +limit+, +offset+, +status+ and +kind+
    # ("newsletter" or "broadcast"). Returns <tt>{ "data", "total" }</tt>.
    def list(params = nil, **filters)
      request("GET", "/v1/posts" + query(payload(params, filters)))
    end

    # Retrieve a post by id.
    def get(id, params = nil, **filters)
      request("GET", "/v1/posts/" + escape(id) + query(payload(params, filters)))
    end

    # Update a draft post (sent posts are immutable). Accepts +subject+, +html+,
    # +text+, +from+, +reply_to+ and +name+.
    def update(id, params = nil, **fields)
      request("PATCH", "/v1/posts/" + escape(id), payload(params, fields))
    end

    # Delete a draft post (sent posts cannot be deleted).
    def delete(id, params = nil, **filters)
      request("DELETE", "/v1/posts/" + escape(id) + query(payload(params, filters)))
    end

    # Send a draft post to the publication's audience — immediately, or at
    # +scheduled_at+ (ISO 8601) if given. Requires the +issues:send+ scope.
    #
    # Like Emails#send this shadows Object#send on the resource object;
    # +__send__+ is untouched.
    def send(id, params = nil, scheduled_at: UNSET, **rest)
      body = payload(params, { scheduled_at: scheduled_at }, rest)
      # An empty body would fail the schema's parse of "{}" on some proxies and
      # says nothing anyway, so an unscheduled send goes out with no body at all.
      request("POST", "/v1/posts/" + escape(id) + "/send", body.empty? ? nil : body)
    end

    # Send a TEST copy of a post to specific recipients to check it before
    # subscribers see it. Renders the post exactly as a subscriber would receive
    # it and delivers a one-shot "[TEST]" email — it does NOT send to the audience.
    #
    # Takes +recipients+ (up to 10), +from+ (must use a verified domain) and
    # optional +reply_to+. Returns <tt>{ "sent_to" => [...], "failed_to" => [...] }</tt>.
    def send_test(id, params = nil, recipients: UNSET, from: UNSET, reply_to: UNSET, **rest)
      body = payload(params, { recipients: recipients, from: from, reply_to: reply_to }, rest)
      request("POST", "/v1/posts/" + escape(id) + "/test", body)
    end
  end
end
