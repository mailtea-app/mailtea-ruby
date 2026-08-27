# frozen_string_literal: true

module Mailtea
  # Raised when the Mailtea API returns an error, or when the client cannot get
  # a request out of the process at all.
  #
  # One class covers both so a caller needs one +rescue+ on the send path:
  # a 422 from the API and a dropped TCP connection are equally a failed send.
  # +status+ tells them apart — it is the HTTP status for an API error and
  # +0+ for a client-side fault (missing key, no transport, unreachable host).
  #
  #   begin
  #     mailtea.emails.send(from: from, to: to, subject: "Hi", html: "<p>Hi</p>")
  #   rescue Mailtea::Error => e
  #     warn e.message     # the API's own message, e.g. "Domain not verified"
  #     e.status           # 422
  #     e.code             # "marketing_plan_required", when the API sends one
  #     e.details          # validation issues, when the API sends them
  #     e.request_id       # the x-request-id header — quote it in support tickets
  #   end
  class Error < StandardError
    # HTTP status code, or 0 for a client-side error.
    attr_reader :status

    # Machine-readable code, when the API sends one (e.g. +marketing_plan_required+)
    # or for a client-side fault (+missing_api_key+, +connection_error+). May be nil.
    # Branching on this survives a copy change to the message.
    attr_reader :code

    # The API's +details+ array (validation issues), when present. May be nil.
    attr_reader :details

    # The API's +x-request-id+ header, for support and debugging. May be nil.
    attr_reader :request_id

    def initialize(message, status: 0, code: nil, details: nil, request_id: nil)
      super(message)
      @status = status
      @code = code
      @details = details
      @request_id = request_id
    end
  end
end
