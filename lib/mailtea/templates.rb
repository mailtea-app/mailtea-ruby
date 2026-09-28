# frozen_string_literal: true

require_relative "resource"

module Mailtea
  # The +templates+ resource (reusable server-side email templates). Reach it at
  # <tt>mailtea.templates</tt>.
  #
  # Templates are scoped to a publication — pass +publication_id+ (except
  # #render, which just renders a spec). Create one from raw +html+, a
  # json-render +spec+, or an +editor_doc+ (a Studio editor design), then
  # #publish it before seeding posts/emails from it.
  class Templates < Resource
    # Render a json-render +spec+ (with optional +variables+) to HTML without
    # creating a template. Returns <tt>{ "html" => ..., "text" => ... }</tt>.
    def render(params = nil, **fields)
      request("POST", "/v1/templates/render", payload(params, fields))
    end

    # Create a template from +html+, a +spec+, OR an +editor_doc+ (exactly one
    # is required — the server renders +html+ from an +editor_doc+, so do not
    # send both). Takes +publication_id+ and +name+, plus optional
    # +style_profile+, +mailtea_theme+, +global_css+, +category+,
    # +preview_image_url+, +tags+, +description+, +text+, +subject+, +from+,
    # +reply_to+ and +variables+.
    def create(params = nil, **fields)
      request("POST", "/v1/templates", payload(params, fields))
    end

    # List templates (cursor-paginated). Filters: +publication_id+ (required),
    # +limit+, +after+ (cursor from a previous +next_cursor+).
    def list(params = nil, **filters)
      request("GET", "/v1/templates" + query(payload(params, filters)))
    end

    # Retrieve a template. Requires +publication_id+.
    def get(id, params = nil, **filters)
      request("GET", "/v1/templates/" + escape(id) + query(payload(params, filters)))
    end

    # Update a template's +name+, +html+/+spec+/+editor_doc+, +style_profile+,
    # +mailtea_theme+, +global_css+, +category+, +preview_image_url+, +tags+,
    # +description+, +text+, +subject+, +from+, +reply_to+ or +variables+. An
    # +editor_doc+ re-renders +html+ server-side, so do not send both.
    #
    # +global_css+, +category+, +preview_image_url+, +tags+, +text+, +subject+,
    # +from+ and +reply_to+ accept +nil+ to clear them. +publication_id+ is
    # required and goes in the query string.
    #
    # Editing a published template no longer unpublishes it: the change is
    # saved as the working copy, the template keeps its published status, and
    # the published version keeps sending until #publish is called again. The
    # reply's +unpublished+ is kept for compatibility and is always +false+
    # now; check +has_unpublished_versions+ on the reply instead (it also
    # carries +message+ when that is +true+).
    def update(id, params = nil, **fields)
      scope, body = Util.split_publication(payload(params, fields))
      request("PATCH", "/v1/templates/" + escape(id) + scope, body)
    end

    # Publish a template so it can seed posts/emails. Requires +publication_id+.
    def publish(id, params = nil, **filters)
      request("POST", "/v1/templates/" + escape(id) + "/publish" + query(payload(params, filters)))
    end

    # Return a published template to draft. +published_at+ is kept — it records
    # that the template was published once, not that it still is. This is now
    # the only way to stop a published template sending, short of deleting it
    # (editing or restoring it no longer does that on its own). It also drops
    # the published version, so the next #publish starts from the current
    # (working) content. Requires +publication_id+.
    def unpublish(id, params = nil, **filters)
      request("POST", "/v1/templates/" + escape(id) + "/unpublish" + query(payload(params, filters)))
    end

    # List a template's design history, newest first. Requires +publication_id+;
    # optional +limit+ (the server caps it at the retained maximum).
    #
    # Entries are metadata only: +version+, +origin+ ("edit", "publish" or
    # "restore"), +restored_from_version+, +format+, +name+, +from+,
    # +reply_to+, +sender_recorded+, +sealed+, +is_current+, +is_published+,
    # +created_at+, +updated_at+ and +author+ (or nil). The design document is
    # never included, because one entry alone can carry half a megabyte of it.
    # +from+ and +reply_to+ are the sender the version holds, and a change to
    # only the From or Reply-To records a version (or folds into the open one,
    # like any edit). +sender_recorded+ says
    # what a nil means: true, the version had none and restoring it clears
    # them; false, the version was recorded before versions kept the sender.
    # +is_current+ marks the entry that matches the working copy
    # (the saved design being edited), which is not always the newest entry: a
    # metadata-only update touches the template without recording a version.
    # +is_published+ (a boolean) marks the entry automations and the API are
    # sending now. They differ while a published template has unpublished
    # changes. +is_published+ is +false+ on every entry of a draft, and on every
    # entry of a template published before the field existed until it is
    # published again.
    #
    # The reply also carries +retention+: only the newest +max_versions+ are
    # kept, and consecutive edits by the same author through the same channel
    # (Studio, or one API key) within +coalesce_window_seconds+ collapse into
    # one entry.
    def versions(id, params = nil, **filters)
      request("GET", "/v1/templates/" + escape(id) + "/versions" + query(payload(params, filters)))
    end

    # Put an older design from #versions back onto the template, with the
    # version's From and Reply-To. A version with +sender_recorded+ false
    # (recorded before versions kept the sender) leaves the current From and
    # Reply-To as they are. Requires +publication_id+.
    #
    # *Restoring no longer unpublishes the template.* It is a content write,
    # and lands in the working copy: a published template keeps its published
    # status and keeps sending its published version until #publish makes the
    # restored design live. The reply's +unpublished+ is kept for
    # compatibility and is always +false+ now; check +has_unpublished_versions+
    # on the returned +template+ (or the reply's +message+) to see whether the
    # restored design is live yet.
    #
    # History is forward-only: the design being replaced is recorded as its own
    # version first, then the restored design is appended as the new newest one.
    # Nothing is rewound or deleted, so a restore is itself undone by restoring
    # the entry directly above it.
    #
    # Restoring the design that is already current writes nothing and returns
    # <tt>restored: false</tt> with <tt>reason: "identical"</tt> and
    # <tt>unpublished: false</tt>. A version that has aged out of retention
    # raises Mailtea::Error with +code+ "template_version_not_found". Returns
    # +restored+, +restored_from_version+, +unpublished+, +message+ and the
    # updated +template+.
    def restore_version(id, version, params = nil, **filters)
      request(
        "POST",
        "/v1/templates/" + escape(id) + "/versions/" + escape(version) + "/restore" +
          query(payload(params, filters))
      )
    end

    # Duplicate a template into a new draft. Requires +publication_id+.
    def duplicate(id, params = nil, **filters)
      request("POST", "/v1/templates/" + escape(id) + "/duplicate" + query(payload(params, filters)))
    end

    # Delete a template. Requires +publication_id+.
    def delete(id, params = nil, **filters)
      request("DELETE", "/v1/templates/" + escape(id) + query(payload(params, filters)))
    end
  end
end
