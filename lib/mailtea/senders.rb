# frozen_string_literal: true

require_relative "resource"

module Mailtea
  # The +senders+ resource (named From identities). Reach it at
  # <tt>mailtea.senders</tt>.
  #
  # Senders are scoped to a publication — pass +publication_id+. #create takes
  # +name+ and +email+ (the address must live on a verified, DKIM-verified email
  # domain), plus optional +reply_to+ and +is_default+. The +email+ is
  # immutable, so #update only changes +name+, +reply_to+ and +is_default+.
  class Senders < Resource
    def create(params = nil, **fields)
      request("POST", "/v1/senders", payload(params, fields))
    end

    # List senders (cursor-paginated). Filters: +publication_id+ (required),
    # +limit+, +after+ (cursor from a previous +next_cursor+).
    def list(params = nil, **filters)
      request("GET", "/v1/senders" + query(payload(params, filters)))
    end

    # Retrieve a sender. Requires +publication_id+.
    def get(id, params = nil, **filters)
      request("GET", "/v1/senders/" + escape(id) + query(payload(params, filters)))
    end

    # Update a sender's +name+, +reply_to+ or +is_default+ (the +email+ is
    # immutable). +publication_id+ is required, in the body.
    def update(id, params = nil, **fields)
      request("PATCH", "/v1/senders/" + escape(id), payload(params, fields))
    end

    # Delete a sender. Requires +publication_id+.
    def delete(id, params = nil, **filters)
      request("DELETE", "/v1/senders/" + escape(id) + query(payload(params, filters)))
    end
  end
end
