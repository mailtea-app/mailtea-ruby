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

  # Domain claims — take a domain back from the team that currently holds it.
  # Reach it at <tt>mailtea.domains.claims</tt>.
  #
  # Use this when adding a domain is refused because the host is connected to
  # another publication: open a claim, publish the TXT record the response
  # lists to prove you control the DNS, then #verify it. On success the other
  # team's domain is released and a fresh one is created for you.
  class DomainClaims < Resource
    # Open a claim. Takes +publication_id+, +name+ and an optional +region+.
    # The response +records+ lists the TXT record to publish.
    def create(params = nil, **fields)
      request("POST", "/v1/domains/claim", payload(params, fields))
    end

    # Poll a claim. Requires +publication_id+.
    def get(id, params = nil, **filters)
      request("GET", "/v1/domains/claims/" + escape(id) + query(payload(params, filters)))
    end

    # Check the TXT record and complete the claim if it is there.
    #
    # Safe to call repeatedly: a record that has not propagated yet leaves the
    # claim pending with the same record, so nothing has to be republished. A
    # completed claim answers with the fresh +domain+ beside the claim.
    def verify(id, params = nil, **filters)
      request("POST",
              "/v1/domains/claims/" + escape(id) + "/verify" + query(payload(params, filters)))
    end

    # Withdraw a pending claim. Requires +publication_id+.
    def cancel(id, params = nil, **filters)
      request("DELETE", "/v1/domains/claims/" + escape(id) + query(payload(params, filters)))
    end
  end

  # The +domains+ resource (email/site sending domains). Reach it at
  # <tt>mailtea.domains</tt>.
  #
  # Scoped to a publication — pass +publication_id+. Register a domain, add the
  # returned DNS +records+, then #verify it before sending from it.
  #
  # #create takes +region+ (fixed at creation), +tls+ and +tracking_subdomain+;
  # #list filters on +region+ and +status+.
  #
  # <tt>update(id, tracking_subdomain: nil)</tt> removes a tracking subdomain:
  # the domain's links go back to being served from the Mailtea host, and links
  # in mail already sent point at the old hostname and stop resolving. The +nil+
  # reaches the wire as an explicit +null+, so omitting the key (leave the
  # subdomain alone) and passing +nil+ (remove it) are different requests. An
  # empty string is neither; it is refused with +tracking_subdomain_invalid+.
  # +nil+ is an update-only value: a create has nothing to clear.
  class Domains < Resource
    # Tracking sub-domains (CNAME) under a domain.
    attr_reader :tracking

    # Domain claims — take a domain back from another publication.
    attr_reader :claims

    def initialize(request)
      super
      @tracking = TrackingDomains.new(request)
      @claims = DomainClaims.new(request)
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
    #
    # <tt>tracking_subdomain: nil</tt> removes the tracking subdomain; leaving
    # the key out leaves it alone. Only the query string drops nils, so the
    # removal travels in the body as an explicit +null+.
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
