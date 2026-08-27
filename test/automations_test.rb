# frozen_string_literal: true

require_relative "test_helper"

STEPS = [{ key: "trigger", type: "trigger_contact_created", config: {} }].freeze

class AutomationsTest < MailteaTest
  def test_validate_creates_nothing
    result = @mailtea.automations.validate(publication_id: "pub_1", steps: STEPS)

    assert_request "POST", "/v1/automations/validate"
    assert_equal "automation_validation", result["object"]
    assert_equal true, result["valid"]
  end

  def test_create_list_get_delete
    created = @mailtea.automations.create(publication_id: "pub_1", name: "Welcome",
                                          steps: STEPS)
    assert_request "POST", "/v1/automations"
    assert_equal "Welcome", last_body["name"]
    assert_equal "draft", created["status"]

    @mailtea.automations.list(publication_id: "pub_1", status: "active")
    assert_request "GET", "/v1/automations"
    assert_equal "active", last_query["status"]

    @mailtea.automations.get("aut_1", publication_id: "pub_1")
    assert_request "GET", "/v1/automations/aut_1"

    @mailtea.automations.delete("aut_1", publication_id: "pub_1")
    assert_request "DELETE", "/v1/automations/aut_1"
  end

  # The route reads publication_id from the query and the body is the graph, so
  # leaving the scope in the body would send a field the schema does not define.
  def test_update_moves_the_publication_out_of_the_body
    @mailtea.automations.update("aut_1", publication_id: "pub_1", steps: STEPS)

    assert_request "PATCH", "/v1/automations/aut_1"
    assert_equal "pub_1", last_query["publication_id"]
    refute last_body.key?("publication_id")
    assert_equal 1, last_body["steps"].length
  end

  def test_activate_pause_and_archive
    @mailtea.automations.activate("aut_1", publication_id: "pub_1")
    assert_request "POST", "/v1/automations/aut_1/activate"
    assert_equal "pub_1", last_query["publication_id"]

    # cancel_runs is read from the body, and its default differs per verb, so an
    # omitted flag has to send no body at all rather than an explicit false.
    paused = @mailtea.automations.pause("aut_1", publication_id: "pub_1")
    assert_request "POST", "/v1/automations/aut_1/pause"
    assert_nil last_body
    assert_equal "paused", paused["status"]

    @mailtea.automations.pause("aut_1", publication_id: "pub_1", cancel_runs: true)
    assert_equal({ "cancel_runs" => true }, last_body)

    archived = @mailtea.automations.archive("aut_1", publication_id: "pub_1")
    assert_request "POST", "/v1/automations/aut_1/archive"
    assert_nil last_body
    assert_equal 3, archived["canceled_runs"]
  end

  def test_versions_version_and_metrics
    @mailtea.automations.versions("aut_1", publication_id: "pub_1", limit: 5)
    assert_request "GET", "/v1/automations/aut_1/versions"

    version = @mailtea.automations.version("aut_1", 3, publication_id: "pub_1")
    assert_request "GET", "/v1/automations/aut_1/versions/3"
    assert_equal 3, version["version"]

    metrics = @mailtea.automations.metrics("aut_1", publication_id: "pub_1", version: 3)
    assert_request "GET", "/v1/automations/aut_1/metrics"
    assert_equal "3", last_query["version"]
    assert_equal true, metrics["excludes_test_runs"]
  end

  def test_test_run_scopes_by_query_and_sends_the_contact_in_the_body
    run = @mailtea.automations.test("aut_1", publication_id: "pub_1", email: "reader@acme.com")

    assert_request "POST", "/v1/automations/aut_1/test"
    assert_equal "pub_1", last_query["publication_id"]
    assert_equal({ "email" => "reader@acme.com" }, last_body)
    assert_equal true, run["is_test"]
  end
end

class AutomationRunsTest < MailteaTest
  def test_list_joins_a_status_array
    @mailtea.automation_runs.list("aut_1", publication_id: "pub_1",
                                           status: %w[running waiting], is_test: false)

    assert_request "GET", "/v1/automations/aut_1/runs"
    assert_equal "running,waiting", last_query["status"]
    # Ruby renders booleans as the "true"/"false" the API's query parser reads.
    assert_equal "false", last_query["is_test"]
  end

  def test_get_and_cancel
    run = @mailtea.automation_runs.get("aut_1", "run_1", publication_id: "pub_1")
    assert_request "GET", "/v1/automations/aut_1/runs/run_1"
    assert_equal "run_1", run["id"]

    canceled = @mailtea.automation_runs.cancel("aut_1", "run_1", publication_id: "pub_1")
    assert_request "POST", "/v1/automations/aut_1/runs/run_1/cancel"
    assert_equal "canceled", canceled["status"]
  end
end

class EventsTest < MailteaTest
  def test_send_records_an_event_for_a_contact
    result = @mailtea.events.send(publication_id: "pub_1", name: "order.placed",
                                  email: "reader@acme.com", properties: { "total" => 42 })

    assert_request "POST", "/v1/events"
    assert_equal "order.placed", last_body["name"]
    assert_equal({ "total" => 42 }, last_body["properties"])
    assert_equal 0, result["resumed_runs"]
  end

  def test_list_filters
    @mailtea.events.list(publication_id: "pub_1", name: "order.placed", limit: 10)

    assert_request "GET", "/v1/events"
    assert_equal "order.placed", last_query["name"]
  end
end

class EventDefinitionsTest < MailteaTest
  def test_create_list_get_update_delete
    created = @mailtea.event_definitions.create(publication_id: "pub_1", name: "order.placed")
    assert_request "POST", "/v1/event-definitions"
    assert_equal "order.placed", created["name"]

    @mailtea.event_definitions.list(publication_id: "pub_1")
    assert_request "GET", "/v1/event-definitions"

    @mailtea.event_definitions.get("evd_1", publication_id: "pub_1")
    assert_request "GET", "/v1/event-definitions/evd_1"

    # The name is immutable and publication_id is the scope, so the body is the
    # schema alone — passing nil clears it back to free-form.
    @mailtea.event_definitions.update("evd_1", publication_id: "pub_1", schema_json: nil)
    assert_request "PATCH", "/v1/event-definitions/evd_1"
    assert_equal "pub_1", last_query["publication_id"]
    refute last_body.key?("publication_id")
    assert last_body.key?("schema_json")
    assert_nil last_body["schema_json"]

    @mailtea.event_definitions.delete("evd_1", publication_id: "pub_1")
    assert_request "DELETE", "/v1/event-definitions/evd_1"
  end
end
