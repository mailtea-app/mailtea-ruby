# frozen_string_literal: true

# The official Ruby SDK for Mailtea — send, schedule, and manage email from your
# app or AI agent.
#
#   require "mailtea"
#
#   mailtea = Mailtea::Client.new
#   mailtea.emails.send(
#     from: "you@yourdomain.com",
#     to: "recipient@example.com",
#     subject: "Hello from Mailtea",
#     html: "<p>Your first email, sent with Mailtea.</p>"
#   )
#
# See Mailtea::Client for the resources, Mailtea::Error for what a failure
# carries, and Mailtea.verify_webhook_signature for inbound webhooks.
module Mailtea
end

require_relative "mailtea/version"
require_relative "mailtea/error"
require_relative "mailtea/response"
require_relative "mailtea/client"
require_relative "mailtea/webhook_signing"
