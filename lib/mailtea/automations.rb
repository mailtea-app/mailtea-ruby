# frozen_string_literal: true

require_relative "resource"

module Mailtea
  # The +automations+ resource (multi-step contact journeys). Reach it at
  # <tt>mailtea.automations</tt>.
  #
  # Automations are scoped to a publication — pass +publication_id+. An
  # automation is a graph: +steps+ (each <tt>{ key:, type:, label:, config: }</tt>)
  # plus optional +connections+ (each <tt>{ from:, to:, branch: }</tt>).
  #
  # +connections+ is optional: omit it and the server links the steps in array
  # order with <tt>branch: "next"</tt>, rooted at the trigger. A graph containing
  # a +condition+ or +wait_for_event+ step cannot be inferred that way and is
  # rejected with +connections_required_for_branching+ — send its connections
  # explicitly.
  #
  # Failures come back as coded +issues+ rather than schema errors, and for a
  # draft/paused/archived automation they ride along informationally instead of
  # blocking the save.
  class Automations < Resource
    # Dry-run a graph without creating anything. Takes +publication_id+ and
    # +steps+, plus optional +connections+. Returns
    # <tt>{ "object" => "automation_validation", "valid" => ..., "issues" => [...] }</tt>.
    def validate(params = nil, **fields)
      request("POST", "/v1/automations/validate", payload(params, fields))
    end

    # Create an automation. Takes +publication_id+, +name+ and +steps+, plus
    # optional +description+, +connections+, +reentry_policy+
    # ("once"/"once_per_window"/"always" — "once_per_window" requires
    # +reentry_window_seconds+), +on_step_failure+ and +validate_only+. With
    # <tt>validate_only: true</tt> nothing is written and an
    # +automation_validation+ is returned instead. New automations start as
    # +draft+ — #activate starts them.
    def create(params = nil, **fields)
      request("POST", "/v1/automations", payload(params, fields))
    end

    # List automations (cursor-paginated). Filters: +publication_id+ (required),
    # +status+ ("draft"/"active"/"paused"/"archived"), +limit+, +after+. List
    # items omit +steps+, +connections+, +valid+ and +issues+ — use #get for the
    # full graph.
    def list(params = nil, **filters)
      request("GET", "/v1/automations" + query(payload(params, filters)))
    end

    # Retrieve one automation with its live graph and current +issues+.
    # Requires +publication_id+.
    def get(id, params = nil, **filters)
      request("GET", "/v1/automations/" + escape(id) + query(payload(params, filters)))
    end

    # Update an automation's +name+, +description+, +steps+, +connections+,
    # +reentry_policy+, +reentry_window_seconds+ or +on_step_failure+.
    # +publication_id+ is required and goes in the query string. The graph is
    # replaced wholesale and cuts a new version.
    #
    # <tt>validate_only: true</tt> returns an +automation_validation+ and writes
    # nothing. A graph change that carries errors saves anyway while the
    # automation is draft/paused/archived; on an +active+ one it is a 422 —
    # pause, save, then start again.
    def update(id, params = nil, **fields)
      scope, body = Util.split_publication(payload(params, fields), keep_in_body: false)
      request("PATCH", "/v1/automations/" + escape(id) + scope, body)
    end

    # Delete an automation. Requires +publication_id+. Deleting an +active+
    # automation is a 409 +automation_active+ — pause or archive it first so its
    # in-flight runs are not dropped silently.
    def delete(id, params = nil, **filters)
      request("DELETE", "/v1/automations/" + escape(id) + query(payload(params, filters)))
    end

    # Start the automation so new contacts enroll. Requires +publication_id+. A
    # graph with errors is refused with 422 +automation_invalid+ and the
    # blocking +issues+.
    def activate(id, params = nil, **filters)
      request("POST", "/v1/automations/" + escape(id) + "/activate" + query(payload(params, filters)))
    end

    # Stop new enrollments. Requires +publication_id+ (query). Optional
    # +cancel_runs+ — it *defaults to false* here, so in-flight runs keep going;
    # pass <tt>cancel_runs: true</tt> to exit them. Returns the automation plus
    # +canceled_runs+.
    def pause(id, params = nil, **fields)
      lifecycle(id, "/pause", payload(params, fields))
    end

    # Archive the automation. Requires +publication_id+ (query). Optional
    # +cancel_runs+ — it *defaults to true* here (the opposite of #pause), so
    # in-flight runs exit with +automation_archived+. Returns the automation plus
    # +canceled_runs+.
    def archive(id, params = nil, **fields)
      lifecycle(id, "/archive", payload(params, fields))
    end

    # List an automation's versions (cursor-paginated). Filters:
    # +publication_id+ (required), +limit+, +after+. List items carry no
    # +steps+/+connections+ — use #version for a stored graph.
    def versions(id, params = nil, **filters)
      request("GET", "/v1/automations/" + escape(id) + "/versions" + query(payload(params, filters)))
    end

    # Retrieve one stored version, including its +steps+ and +connections+.
    # Requires +publication_id+. This is the graph a run of that version is
    # pinned to — editing the automation never rewrites it.
    def version(id, version, params = nil, **filters)
      request(
        "GET",
        "/v1/automations/" + escape(id) + "/versions/" + escape(version) +
          query(payload(params, filters))
      )
    end

    # Per-step funnel counts for an automation. Filters: +publication_id+
    # (required), +version+ (omit to aggregate across ALL versions), +since+,
    # +until+ (ISO 8601). Test runs are always excluded
    # (<tt>excludes_test_runs: true</tt>). Condition steps report
    # <tt>branches: { condition_met, condition_not_met }</tt>, +wait_for_event+
    # steps <tt>{ event_received, timeout }</tt>.
    def metrics(id, params = nil, **filters)
      request("GET", "/v1/automations/" + escape(id) + "/metrics" + query(payload(params, filters)))
    end

    # Run the automation once against a real contact. +publication_id+ is
    # required and goes in the query string; the body takes one of +contact_id+
    # or +email+, plus optional +event_properties+ to seed the run's +event.*+
    # namespace.
    #
    # A test run *sends real, billed email* to that inbox — it does not bypass
    # any send gate. It is flagged +is_test+ and excluded from #metrics. Returns
    # 202 with the queued run.
    def test(id, params = nil, **fields)
      scope, body = Util.split_publication(payload(params, fields), keep_in_body: false)
      request("POST", "/v1/automations/" + escape(id) + "/test" + scope, body)
    end

    private

    # +publication_id+ goes in the query but +cancel_runs+ is read from the body,
    # so the two are split here. No body is sent when the caller omitted
    # +cancel_runs+ — or passed it as +nil+, which the server's schema would
    # reject — so the per-verb default applies in both cases.
    def lifecycle(id, suffix, merged)
      cancel_runs = merged["cancel_runs"]
      body = cancel_runs.nil? ? nil : { "cancel_runs" => cancel_runs }
      request(
        "POST",
        "/v1/automations/" + escape(id) + suffix +
          query({ "publication_id" => merged["publication_id"] }),
        body
      )
    end
  end
end
