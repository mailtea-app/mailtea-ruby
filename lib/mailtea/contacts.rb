# frozen_string_literal: true

require_relative "resource"

module Mailtea
  # The +contacts+ resource. Reach it at <tt>mailtea.contacts</tt>.
  #
  # Audience resources are scoped to a publication — pass +publication_id+.
  class Contacts < Resource
    # Create a contact — or update it if the email already exists in the
    # publication (the endpoint upserts). #upsert is the same call.
    #
    # Takes +publication_id+ and +email+, plus optional +status+
    # ("active"/"unsubscribed"/"suppressed").
    def create(params = nil, publication_id: UNSET, email: UNSET, status: UNSET, **rest)
      body = payload(
        params,
        { publication_id: publication_id, email: email, status: status },
        rest
      )
      request("POST", "/v1/contacts", body)
    end

    # Create the contact or update it in place — an alias of #create, named for
    # what <tt>POST /v1/contacts</tt> actually does.
    def upsert(params = nil, **fields)
      create(params, **fields)
    end

    # List contacts (cursor-paginated). Filters: +publication_id+ (required),
    # +status+ ("active"/"unsubscribed"/"suppressed"), +search+ (matches the
    # email address), +limit+, +after+ (cursor from a previous +next_cursor+).
    def list(params = nil, **filters)
      request("GET", "/v1/contacts" + query(payload(params, filters)))
    end

    # Retrieve a contact by id or by email address. Requires +publication_id+.
    def get(id_or_email, params = nil, **filters)
      request("GET", "/v1/contacts/" + escape(id_or_email) + query(payload(params, filters)))
    end

    # Update a contact by id or email — currently its +status+.
    # +publication_id+ is required and goes in the query string.
    def update(id_or_email, params = nil, publication_id: UNSET, status: UNSET, **rest)
      merged = payload(params, { publication_id: publication_id, status: status }, rest)
      scope, body = Util.split_publication(merged)
      request("PATCH", "/v1/contacts/" + escape(id_or_email) + scope, body)
    end

    # Delete a contact by id or email. Requires +publication_id+.
    def delete(id_or_email, params = nil, **filters)
      request("DELETE", "/v1/contacts/" + escape(id_or_email) + query(payload(params, filters)))
    end
  end
end
