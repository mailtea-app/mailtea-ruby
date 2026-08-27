# frozen_string_literal: true

require_relative "resource"

module Mailtea
  # The +webhooks+ resource (outbound event subscriptions). Reach it at
  # <tt>mailtea.webhooks</tt>.
  #
  # Scoped to a publication — pass +publication_id+. #create returns the
  # +signing_secret+ once; store it and verify deliveries with
  # Mailtea.verify_webhook_signature.
  class Webhooks < Resource
    BASE = "/v1/webhooks/endpoints"

    # Create an endpoint. Takes +publication_id+, +url+ and +events+.
    def create(params = nil, **fields)
      request("POST", BASE, payload(params, fields))
    end

    # List endpoints. Requires +publication_id+.
    def list(params = nil, **filters)
      request("GET", BASE + query(payload(params, filters)))
    end

    # Retrieve an endpoint. Requires +publication_id+.
    def get(id, params = nil, **filters)
      request("GET", BASE + "/" + escape(id) + query(payload(params, filters)))
    end

    # Update an endpoint's +url+, +events+ or +enabled+. +publication_id+ is
    # required and goes in the query string.
    def update(id, params = nil, **fields)
      scope, body = Util.split_publication(payload(params, fields))
      request("PATCH", BASE + "/" + escape(id) + scope, body)
    end

    # Delete an endpoint. Requires +publication_id+.
    def delete(id, params = nil, **filters)
      request("DELETE", BASE + "/" + escape(id) + query(payload(params, filters)))
    end
  end
end
