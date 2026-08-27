# frozen_string_literal: true

require_relative "resource"

module Mailtea
  # Attachments on a received email. Reach it at
  # <tt>mailtea.emails.inbound.attachments</tt>.
  #
  # Each returned object carries a short-lived signed +download_url+.
  class InboundAttachments < Resource
    BASE = "/v1/emails/inbound"

    # List an inbound email's attachments, each with a signed download URL.
    def list(id)
      request("GET", BASE + "/" + escape(id) + "/attachments")
    end

    # Retrieve a single inbound attachment with a signed download URL.
    def get(id, attachment_id)
      request("GET", BASE + "/" + escape(id) + "/attachments/" + escape(attachment_id))
    end
  end

  # Inbound (received) emails. Reach it at <tt>mailtea.emails.inbound</tt>.
  #
  # List and retrieve mail delivered to your receiving domains, download
  # attachments, and #reply — which threads correctly by construction and reuses
  # the transactional send pipeline. Scoped to a publication: pass
  # +publication_id+ to #list.
  class InboundEmails < Resource
    BASE = "/v1/emails/inbound"

    # Attachments on a received email.
    attr_reader :attachments

    def initialize(request)
      super
      @attachments = InboundAttachments.new(request)
    end

    # List received emails in a publication (most recent first), cursor-paginated.
    # Takes +publication_id+, optional +limit+ (1-100, default 20) and +cursor+.
    def list(params = nil, **filters)
      request("GET", BASE + query(payload(params, filters)))
    end

    # Retrieve a single received email, including its body, headers, and attachments.
    def get(id)
      request("GET", BASE + "/" + escape(id))
    end

    # Reply to a received email. The reply target (+to+), the threading headers
    # and the "Re: " subject default are all server-derived — pass only the
    # content. Returns the resulting transactional email's +id+ and +status+.
    def reply(id, params = nil, html: UNSET, text: UNSET, from: UNSET, subject: UNSET,
              cc: UNSET, bcc: UNSET, idempotency_key: UNSET, **rest)
      body = payload(
        params,
        { html: html, text: text, from: from, subject: subject,
          cc: cc, bcc: bcc, idempotency_key: idempotency_key },
        rest
      )
      request("POST", BASE + "/" + escape(id) + "/reply", body)
    end
  end
end
