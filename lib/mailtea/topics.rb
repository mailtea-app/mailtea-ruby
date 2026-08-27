# frozen_string_literal: true

require_relative "resource"

module Mailtea
  # The +topics+ resource (topic definitions). Reach it at <tt>mailtea.topics</tt>.
  #
  # Topics are scoped to a publication — pass +publication_id+. This manages
  # topic definitions only; assigning topics to contacts is not yet exposed.
  class Topics < Resource
    # Create a topic definition. Requires +publication_id+, +name+ and
    # +default_subscription+ ("opt_in" or "opt_out"). Optional +description+ and
    # +visibility+ ("private" by default; "public" makes the topic appear on the
    # reader preference page as its own subscription).
    def create(params = nil, publication_id: UNSET, name: UNSET,
               default_subscription: UNSET, description: UNSET, visibility: UNSET, **rest)
      body = payload(
        params,
        { publication_id: publication_id, name: name,
          default_subscription: default_subscription, description: description,
          visibility: visibility },
        rest
      )
      request("POST", "/v1/topics", body)
    end

    # List topic definitions. Filters: +publication_id+ (required), +limit+, +after+.
    def list(params = nil, **filters)
      request("GET", "/v1/topics" + query(payload(params, filters)))
    end

    # Retrieve a topic definition. Requires +publication_id+.
    def get(id, params = nil, **filters)
      request("GET", "/v1/topics/" + escape(id) + query(payload(params, filters)))
    end

    # Update a topic's +name+, +description+, +default_subscription+ or
    # +visibility+. +publication_id+ is required and goes in the query string.
    def update(id, params = nil, **fields)
      scope, body = Util.split_publication(payload(params, fields))
      request("PATCH", "/v1/topics/" + escape(id) + scope, body)
    end

    # Delete a topic definition. Requires +publication_id+.
    def delete(id, params = nil, **filters)
      request("DELETE", "/v1/topics/" + escape(id) + query(payload(params, filters)))
    end
  end
end
