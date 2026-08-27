# frozen_string_literal: true

require_relative "resource"

module Mailtea
  # Tracking sub-domains (CNAME) under a domain — used to serve open-pixel and
  # click-tracking links from your own domain. Reach it at
  # <tt>mailtea.domains.tracking</tt>.
  class TrackingDomains < Resource
    # Add a tracking sub-domain. Takes +publication_id+ and +subdomain+. The
    # response +records+ lists the CNAME to add.
    def create(domain_id, params = nil, **fields)
      merged = payload(params, fields)
      request(
        "POST",
        "/v1/domains/" + escape(domain_id) + "/tracking-domains" +
          query({ "publication_id" => merged["publication_id"] }),
        { "subdomain" => merged["subdomain"] }
      )
    end

    # List a domain's tracking sub-domains. Requires +publication_id+.
    def list(domain_id, params = nil, **filters)
      request(
        "GET",
        "/v1/domains/" + escape(domain_id) + "/tracking-domains" + query(payload(params, filters))
      )
    end

    # Verify a tracking sub-domain's CNAME. Requires +publication_id+.
    def verify(domain_id, tracking_domain_id, params = nil, **filters)
      request(
        "POST",
        "/v1/domains/" + escape(domain_id) + "/tracking-domains/" +
          escape(tracking_domain_id) + "/verify" + query(payload(params, filters))
      )
    end

    # Delete a tracking sub-domain. Requires +publication_id+.
    def delete(domain_id, tracking_domain_id, params = nil, **filters)
      request(
        "DELETE",
        "/v1/domains/" + escape(domain_id) + "/tracking-domains/" +
          escape(tracking_domain_id) + query(payload(params, filters))
      )
    end
  end

  # The +domains+ resource (email/site sending domains). Reach it at
  # <tt>mailtea.domains</tt>.
  #
  # Scoped to a publication — pass +publication_id+. Register a domain, add the
  # returned DNS +records+, then #verify it before sending from it.
  class Domains < Resource
    # Tracking sub-domains (CNAME) under a domain.
    attr_reader :tracking

    def initialize(request)
      super
      @tracking = TrackingDomains.new(request)
    end

    # Register a domain. The response +records+ lists the DNS records to add.
    def create(params = nil, **fields)
      request("POST", "/v1/domains", payload(params, fields))
    end

    # List domains. Requires +publication_id+.
    def list(params = nil, **filters)
      request("GET", "/v1/domains" + query(payload(params, filters)))
    end

    # Retrieve a domain with its DNS records and status. Requires +publication_id+.
    def get(id, params = nil, **filters)
      request("GET", "/v1/domains/" + escape(id) + query(payload(params, filters)))
    end

    # Verify a domain via its DNS records; +status+ becomes "verified".
    def verify(id, params = nil, **filters)
      request("POST", "/v1/domains/" + escape(id) + "/verify" + query(payload(params, filters)))
    end

    # Update a domain — including +custom_return_path+, which delegates a
    # subdomain as the envelope sender so SPF aligns with your own domain. Mail
    # keeps sending on the default return-path until the delegated DNS resolves.
    # +publication_id+ is required and goes in the query string.
    def update(id, params = nil, **fields)
      scope, body = Util.split_publication(payload(params, fields))
      request("PATCH", "/v1/domains/" + escape(id) + scope, body)
    end

    # Delete a domain. Requires +publication_id+.
    def delete(id, params = nil, **filters)
      request("DELETE", "/v1/domains/" + escape(id) + query(payload(params, filters)))
    end
  end
end
