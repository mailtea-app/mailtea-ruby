# frozen_string_literal: true

require_relative "resource"

module Mailtea
  # The +segments+ resource. Reach it at <tt>mailtea.segments</tt>.
  #
  # Audience segments are scoped to a publication — pass +publication_id+. To
  # clear a nullable filter on update pass +nil+ (e.g. <tt>status_filter: nil</tt>);
  # omit the keyword to leave it unchanged.
  class Segments < Resource
    # Create a segment. Takes +publication_id+ and +name+, plus optional
    # +description+, +status_filter+ and +query_filter+.
    def create(params = nil, **fields)
      request("POST", "/v1/segments", payload(params, fields))
    end

    # List segments. Filters: +publication_id+ (required), +limit+, +after+.
    def list(params = nil, **filters)
      request("GET", "/v1/segments" + query(payload(params, filters)))
    end

    # Retrieve a segment. Requires +publication_id+.
    def get(id, params = nil, **filters)
      request("GET", "/v1/segments/" + escape(id) + query(payload(params, filters)))
    end

    # Update a segment's +name+, +description+, +status_filter+ or
    # +query_filter+. +publication_id+ is required and goes in the query string.
    def update(id, params = nil, **fields)
      scope, body = Util.split_publication(payload(params, fields))
      request("PATCH", "/v1/segments/" + escape(id) + scope, body)
    end

    # Delete a segment. Requires +publication_id+.
    def delete(id, params = nil, **filters)
      request("DELETE", "/v1/segments/" + escape(id) + query(payload(params, filters)))
    end
  end
end
