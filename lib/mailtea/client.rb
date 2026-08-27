# frozen_string_literal: true

require "json"

require_relative "api_keys"
require_relative "assets"
require_relative "automation_runs"
require_relative "automations"
require_relative "contact_properties"
require_relative "contacts"
require_relative "domains"
require_relative "emails"
require_relative "error"
require_relative "events"
require_relative "posts"
require_relative "response"
require_relative "segments"
require_relative "senders"
require_relative "suppressions"
require_relative "templates"
require_relative "topics"
require_relative "transport"
require_relative "version"
require_relative "webhooks"

module Mailtea
  DEFAULT_BASE_URL = "https://api.mailtea.app"

  # The Mailtea client.
  #
  #   require "mailtea"
  #
  #   mailtea = Mailtea::Client.new            # reads MAILTEA_API_KEY
  #   sent = mailtea.emails.send(
  #     from: "you@yourdomain.com",
  #     to: "recipient@example.com",
  #     subject: "Hello",
  #     html: "<p>Sent with Mailtea.</p>"
  #   )
  #   sent["id"]
  #
  # The API key may be passed explicitly or read from +MAILTEA_API_KEY+.
  # Self-hosting or local dev: pass +base_url+ or set +MAILTEA_API_BASE_URL+.
  class Client
    # Transactional email: send, batch, status, scheduling, inbound.
    attr_reader :emails
    # Audience contacts.
    attr_reader :contacts
    # Newsletter posts/issues.
    attr_reader :posts
    # Audience segments.
    attr_reader :segments
    # Named From identities.
    attr_reader :senders
    # The publication's image library.
    attr_reader :assets
    # The team-wide do-not-send list.
    attr_reader :suppressions
    # Topic definitions.
    attr_reader :topics
    # Reusable server-side email templates.
    attr_reader :templates
    # Sending domains and their tracking sub-domains.
    attr_reader :domains
    # Outbound event subscriptions.
    attr_reader :webhooks
    # Custom contact fields (team-scoped).
    attr_reader :contact_properties
    # API keys.
    attr_reader :api_keys
    # Multi-step contact journeys.
    attr_reader :automations
    # One contact's journey through one automation.
    attr_reader :automation_runs
    # Custom product events.
    attr_reader :events
    # The catalog of event names a publication expects.
    attr_reader :event_definitions

    # The base URL every request is built on, with any trailing slash removed.
    attr_reader :base_url

    def initialize(api_key = nil, base_url: nil, transport: nil)
      key = api_key || ENV["MAILTEA_API_KEY"]
      if key.nil? || key.empty?
        raise Error.new(
          "Missing Mailtea API key. Pass it to Mailtea::Client.new(api_key) or set " \
          "the MAILTEA_API_KEY environment variable.",
          code: "missing_api_key"
        )
      end

      @api_key = key
      configured = base_url || ENV["MAILTEA_API_BASE_URL"]
      configured = nil if configured.nil? || configured.empty?
      @base_url = (configured || DEFAULT_BASE_URL).chomp("/")
      @transport = transport || Transport

      requester = method(:perform)
      @emails = Emails.new(requester)
      @contacts = Contacts.new(requester)
      @posts = Posts.new(requester)
      @segments = Segments.new(requester)
      @senders = Senders.new(requester)
      @assets = Assets.new(requester)
      @suppressions = Suppressions.new(requester)
      @topics = Topics.new(requester)
      @templates = Templates.new(requester)
      @domains = Domains.new(requester)
      @webhooks = Webhooks.new(requester)
      @contact_properties = ContactProperties.new(requester)
      @api_keys = ApiKeys.new(requester)
      @automations = Automations.new(requester)
      @automation_runs = AutomationRuns.new(requester)
      @events = Events.new(requester)
      @event_definitions = EventDefinitions.new(requester)
    end

    # Keeps the key out of `p client` and out of any exception report that
    # inspects the object.
    def inspect
      "#<Mailtea::Client base_url=#{@base_url.inspect}>"
    end

    private

    def perform(method, path, body = nil, raw: false)
      headers = {
        "Authorization" => "Bearer #{@api_key}",
        "Accept" => "application/json",
        "User-Agent" => "mailtea-ruby/#{VERSION}"
      }
      encoded = nil
      unless body.nil?
        headers["Content-Type"] = "application/json"
        encoded = JSON.generate(body)
      end

      response = @transport.call(method, @base_url + path, headers, encoded)
      request_id = response.headers["x-request-id"]

      raise error_from(response, request_id) if response.status >= 400

      return nil if response.status == 204 || response.body.to_s.empty?
      # A few endpoints (suppressions export) answer with something other than
      # JSON — hand back the body untouched instead of parsing it.
      return response.body if raw

      parse(response.body)
    end

    def error_from(response, request_id)
      message = "HTTP #{response.status}"
      code = nil
      details = nil

      parsed = begin
        JSON.parse(response.body.to_s)
      rescue JSON::ParserError
        nil # non-JSON body — keep the status-line message
      end

      if parsed.is_a?(Hash)
        message = parsed["error"] if parsed["error"].is_a?(String) && !parsed["error"].empty?
        details = parsed["details"]
        # Machine-readable code from the API, when it sends one (e.g.
        # "marketing_plan_required" on 402). Branching on code survives a copy
        # change to the message.
        code = parsed["code"] if parsed["code"].is_a?(String)
      end

      Error.new(message, status: response.status, code: code, details: details,
                         request_id: request_id)
    end

    def parse(text)
      JSON.parse(text, object_class: Response)
    rescue JSON::ParserError => e
      raise Error.new("Could not parse the Mailtea API response as JSON: #{e.message}",
                      code: "invalid_response")
    end
  end
end
