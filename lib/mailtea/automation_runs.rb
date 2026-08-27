# frozen_string_literal: true

require_relative "resource"

module Mailtea
  # The +automation_runs+ resource (one contact's journey through one
  # automation). Reach it at <tt>mailtea.automation_runs</tt>.
  #
  # Runs are nested under an automation and scoped to a publication — pass
  # +automation_id+ and +publication_id+. A run PINS the automation version it
  # started on, so #get returns the graph the run is actually executing, not the
  # live one.
  class AutomationRuns < Resource
    # List an automation's runs (cursor-paginated). Filters: +publication_id+
    # (required), +status+ (one or more run statuses — pass an Array and it is
    # joined for you), +contact_id+, +is_test+, +limit+, +after+. List items omit
    # the pinned graph and the step runs; use #get for those.
    def list(automation_id, params = nil, **filters)
      merged = payload(params, filters)
      status = merged["status"]
      merged["status"] = status.join(",") if status.is_a?(Array)
      request("GET", "/v1/automations/" + escape(automation_id) + "/runs" + query(merged))
    end

    # Retrieve one run in full. Requires +publication_id+. Returns the PINNED
    # +steps+/+connections+, the per-step +step_runs+, and +waiting+
    # (+resume_at+ / +waiting_event_name+) — read this rather than an event
    # ingest's +resumed_runs+ counter to tell whether an event actually advanced
    # the run.
    def get(automation_id, run_id, params = nil, **filters)
      request(
        "GET",
        "/v1/automations/" + escape(automation_id) + "/runs/" + escape(run_id) +
          query(payload(params, filters))
      )
    end

    # Cancel one in-flight run. Requires +publication_id+. A cancelled run cannot
    # be resumed. Returns the run in full detail.
    def cancel(automation_id, run_id, params = nil, **filters)
      request(
        "POST",
        "/v1/automations/" + escape(automation_id) + "/runs/" + escape(run_id) + "/cancel" +
          query(payload(params, filters))
      )
    end
  end
end
