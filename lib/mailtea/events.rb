# frozen_string_literal: true

require_relative "resource"

module Mailtea
  # The +events+ resource (custom product events that trigger automations and
  # resume +wait_for_event+ steps). Reach it at <tt>mailtea.events</tt>.
  #
  # Events are scoped to a publication — pass +publication_id+.
  class Events < Resource
    # Record an event for a contact. Takes +publication_id+, +name+, and exactly
    # one of +contact_id+ or +email+ (both is a 400 +contact_reference_conflict+,
    # neither a 400 +contact_reference_required+). Optional: +create_contact+,
    # +properties+, +occurred_at+, +idempotency_key+.
    #
    # +create_contact+ is *opt-in* — without it an unresolvable address is a 404
    # +contact_not_found+ rather than a new contact.
    #
    # Returns 202 with +enrolled_automations+ and +resumed_runs+. A replay of the
    # same +idempotency_key+ returns the ORIGINAL event id with
    # <tt>replayed: true</tt> and always reports <tt>enrolled_automations: 0,
    # resumed_runs: 0</tt>. Note that <tt>resumed_runs: 0</tt> on a FRESH ingest
    # does not prove nothing matched — a run being advanced concurrently is
    # invisible for that instant, so read the run itself
    # (Mailtea::AutomationRuns#get) rather than the counter.
    #
    # Like Emails#send this shadows Object#send on the resource object;
    # +__send__+ is untouched.
    def send(params = nil, **fields)
      request("POST", "/v1/events", payload(params, fields))
    end

    # List recorded events (cursor-paginated). Filters: +publication_id+
    # (required), +name+, +contact_id+, +limit+, +after+ (cursor from a previous
    # +next_cursor+).
    def list(params = nil, **filters)
      request("GET", "/v1/events" + query(payload(params, filters)))
    end
  end

  # The +event_definitions+ resource (the catalog of event names a publication
  # expects, with optional property schemas). Reach it at
  # <tt>mailtea.event_definitions</tt>.
  #
  # Definitions are scoped to a publication — pass +publication_id+. They are
  # documentation and tooling, not a gate: Events#send accepts an event with no
  # definition.
  class EventDefinitions < Resource
    # Create an event definition. Takes +publication_id+ and +name+, plus
    # optional +description+ and +schema_json+. The name is immutable once created.
    def create(params = nil, **fields)
      request("POST", "/v1/event-definitions", payload(params, fields))
    end

    # List event definitions (cursor-paginated). Filters: +publication_id+
    # (required), +limit+, +after+. List items carry no +inferred_properties+ —
    # use #get for those.
    def list(params = nil, **filters)
      request("GET", "/v1/event-definitions" + query(payload(params, filters)))
    end

    # Retrieve one definition. Requires +publication_id+. Adds
    # +schema_properties+ and +inferred_properties+ — the latter computed on read
    # over the last 500 events, reporting each key's type, sample count and
    # *coverage*. Low coverage is the trap: a condition on a key present in 3% of
    # events will almost never match.
    def get(id, params = nil, **filters)
      request("GET", "/v1/event-definitions/" + escape(id) + query(payload(params, filters)))
    end

    # Update a definition's +description+ or +schema_json+ (+nil+ clears the
    # schema back to free-form). +publication_id+ is required and goes in the
    # query string. +name+ is immutable — sending it is a 400
    # +event_name_immutable+, not a silently dropped rename.
    def update(id, params = nil, **fields)
      scope, body = Util.split_publication(payload(params, fields), keep_in_body: false)
      request("PATCH", "/v1/event-definitions/" + escape(id) + scope, body)
    end

    # Delete an event definition. Requires +publication_id+. Events already
    # recorded under that name are untouched.
    def delete(id, params = nil, **filters)
      request("DELETE", "/v1/event-definitions/" + escape(id) + query(payload(params, filters)))
    end
  end
end
