# frozen_string_literal: true

require_relative "resource"

module Mailtea
  # The +api_keys+ resource. Reach it at <tt>mailtea.api_keys</tt>.
  #
  # Requires a token with +settings:write+. A key can never be granted scopes the
  # calling token does not already hold.
  class ApiKeys < Resource
    # Create an API key. The +token+ is returned ONCE — store it securely.
    #
    # Takes +name+, optional +permission+ ("full_access" or "sending_access"),
    # optional +domain_id+, and optional +mode+.
    #
    # +mode+ is "live" (the default) or "test". A test key is prefixed
    # <tt>mt_test_</tt>: its sends are validated, recorded and emit webhooks but
    # are never delivered, and it reads only test mail. It is NOT a data sandbox
    # — it reads and writes your real contacts, templates, senders and webhooks.
    # Only delivery is simulated.
    def create(params = nil, **fields)
      request("POST", "/v1/api-keys", payload(params, fields))
    end

    # List API keys (token values are never returned).
    def list
      request("GET", "/v1/api-keys")
    end

    # Revoke (delete) an API key by id.
    def revoke(id)
      request("DELETE", "/v1/api-keys/" + escape(id))
    end
  end
end
