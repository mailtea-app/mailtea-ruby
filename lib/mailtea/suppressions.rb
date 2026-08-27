# frozen_string_literal: true

require_relative "resource"

module Mailtea
  # The +suppressions+ resource (the org-wide do-not-send list). Reach it at
  # <tt>mailtea.suppressions</tt>.
  #
  # Suppressions are team-scoped — there is no +publication_id+.
  class Suppressions < Resource
    # List suppression entries (cursor-paginated). Optional filters: +reason+,
    # +q+ (email search), +created_after+, +created_before+, +limit+,
    # +starting_after+ (cursor from a previous +next_cursor+).
    def list(params = nil, **filters)
      request("GET", "/v1/suppressions" + query(payload(params, filters)))
    end

    # Add addresses to the suppression list. Takes +emails+ (an Array, up to
    # 1000) and an optional +reason+. Returns <tt>{ "added" => ... }</tt>.
    def add(params = nil, **fields)
      request("POST", "/v1/suppressions", payload(params, fields))
    end

    # Remove addresses from the suppression list. Takes +emails+ (an Array).
    # Returns <tt>{ "removed" => ... }</tt>.
    def remove(params = nil, **fields)
      request("DELETE", "/v1/suppressions", payload(params, fields))
    end

    # Export the whole suppression list as CSV. Returns the raw text/csv body
    # ("email,reason,source,created_at" with a header row) as a String, not a
    # parsed response.
    def export
      request("GET", "/v1/suppressions/export", nil, raw: true)
    end
  end
end
