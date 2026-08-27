# frozen_string_literal: true

require_relative "resource"

module Mailtea
  # The +contact_properties+ resource (custom contact fields). Reach it at
  # <tt>mailtea.contact_properties</tt>.
  #
  # Definitions are team-scoped — there is no +publication_id+. #create takes
  # +key+ and +type+ ("string" or "number").
  class ContactProperties < Resource
    def create(params = nil, **fields)
      request("POST", "/v1/contact-properties", payload(params, fields))
    end

    def list(params = nil, **filters)
      request("GET", "/v1/contact-properties" + query(payload(params, filters)))
    end

    # Update a definition's +description+ or +fallback_value+ (+nil+ clears the
    # fallback). The +key+ and +type+ are immutable.
    def update(id, params = nil, **fields)
      request("PATCH", "/v1/contact-properties/" + escape(id), payload(params, fields))
    end

    def delete(id)
      request("DELETE", "/v1/contact-properties/" + escape(id))
    end
  end
end
