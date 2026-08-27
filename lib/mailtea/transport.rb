# frozen_string_literal: true

require "json"
require "net/http"
require "openssl"
require "uri"

require_relative "error"

module Mailtea
  # What a transport hands back: the HTTP status, the response headers with
  # lowercased names, and the body as an undecoded String.
  HttpResponse = Struct.new(:status, :headers, :body, keyword_init: true)

  # The default HTTP transport: +net/http+ and +json+ from the standard library,
  # no gems.
  #
  # A transport is anything that responds to
  # <tt>call(method, url, headers, body) -> HttpResponse</tt>. Pass your own to
  # <tt>Mailtea::Client.new(..., transport:)</tt> to record requests in tests, to
  # route through a proxy or an instrumented HTTP stack, or to reuse a connection
  # pool. Everything the client does above the wire — auth header, JSON encoding,
  # error mapping — stays the same.
  module Transport
    VERBS = {
      "GET" => Net::HTTP::Get,
      "POST" => Net::HTTP::Post,
      "PATCH" => Net::HTTP::Patch,
      "DELETE" => Net::HTTP::Delete
    }.freeze

    OPEN_TIMEOUT_SECONDS = 10
    READ_TIMEOUT_SECONDS = 30

    module_function

    def call(method, url, headers, body)
      uri = parse_url(url)
      request_class = VERBS.fetch(method) do
        raise Error.new("Unsupported HTTP method #{method}", code: "unsupported_method")
      end

      request = request_class.new(uri)
      headers.each { |name, value| request[name] = value }
      # Net::HTTP::Delete has no request body by convention, but the API's
      # suppressions removal takes one, and setting it here still sends it.
      request.body = body if body
      # A bodyless POST (cancel, publish, verify, activate…) is given an empty
      # body by Net::HTTP, which then labels it application/x-www-form-urlencoded
      # — a lie about a JSON API, and a warning under -w. Say what this client
      # actually speaks instead.
      if body.nil? && request.request_body_permitted?
        request["Content-Type"] ||= "application/json"
      end

      response = Net::HTTP.start(
        uri.hostname,
        uri.port,
        use_ssl: uri.scheme == "https",
        open_timeout: OPEN_TIMEOUT_SECONDS,
        read_timeout: READ_TIMEOUT_SECONDS
      ) { |http| http.request(request) }

      HttpResponse.new(
        status: response.code.to_i,
        headers: lowercased(response),
        body: response.body.to_s
      )
    rescue Timeout::Error, SystemCallError, SocketError, IOError, OpenSSL::SSL::SSLError,
           URI::InvalidURIError => e
      # A request that never lands is as much a failed send as a 500, and the
      # caller should only have to rescue one class. status 0 says it never
      # reached the API.
      # parse_url guarantees a URI::HTTP by here, so host and port are known.
      raise Error.new(
        "Could not reach Mailtea at #{uri.scheme}://#{uri.host}:#{uri.port}: " \
        "#{e.class}: #{e.message}",
        code: "connection_error"
      )
    end

    # A base URL that is not http(s) is a configuration mistake, not a network
    # fault, and it has to arrive as Mailtea::Error like every other failure —
    # the whole point of the one-rescue contract is that nothing else escapes.
    # Left alone, the two ways to get it wrong both break that: Net::HTTP.start
    # answers "api.mailtea.app" (no scheme) with a bare ArgumentError, and
    # URI.parse answers "127.0.0.1:7787" — the classic MAILTEA_API_BASE_URL
    # typo, since a host:port reads as scheme:opaque — with InvalidURIError.
    def parse_url(url)
      uri = URI.parse(url)
      return uri if uri.is_a?(URI::HTTP) # URI::HTTPS is a subclass

      raise invalid_base_url(url)
    rescue URI::InvalidURIError
      raise invalid_base_url(url)
    end

    def invalid_base_url(url)
      # Report the base rather than the whole URL: every path this client builds
      # starts at "/v1", so the split leaves exactly the configured part — and
      # keeps recipient addresses out of the message when the query held one.
      Error.new(
        "Mailtea's base URL must be an http:// or https:// URL — got " \
        "#{url.split("/v1", 2).first.inspect}. Check MAILTEA_API_BASE_URL, or the " \
        "base_url: passed to Mailtea::Client.new.",
        code: "invalid_base_url"
      )
    end

    def lowercased(response)
      headers = {}
      response.each_header { |name, value| headers[name.downcase] = value }
      headers
    end
  end
end
