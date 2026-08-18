require "minitest/autorun"
require_relative "../lib/snippetion"

class SnippetionTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def setup
    @app = Snippetion::App.new(root: ROOT)
    @project = Snippetion::Project.load(root: ROOT, group: "bash", project: "test")
    @access_token = "preview-token"
    @secured_app = Snippetion::App.new(root: ROOT, access_token: @access_token)
  end

  def test_parses_required_and_optional_parts
    assert_equal 5, @project.parts.length
    assert_equal 3, @project.optional_parts.length
    assert_equal ["part1", "part5"], @project.parts.select(&:required).map(&:name)
  end

  def test_renders_selected_optional_parts_by_choice_bits
    assert_equal "#!/bin/bash\nexport B=aaa\necho $B $D\n", @project.render("2")
    assert_equal "#!/bin/bash\necho A\necho $B $D\n", @project.render("1")
    assert_equal "#!/bin/bash\necho A\nexport B=aaa\nexport D=ggg\necho $B $D\n", @project.render("7")
    assert_equal "#!/bin/bash\necho A\nexport B=aaa\necho $B $D\n", @project.render("z")
  end

  def test_app_serves_group_project_choice_route
    status, headers, body = @app.call(method: "GET", path: "/bash/test/3")

    assert_equal 200, status
    assert_equal "text/plain; charset=utf-8", headers["Content-Type"]
    assert_equal "#!/bin/bash\necho A\nexport B=aaa\necho $B $D\n", body
  end

  def test_app_defaults_to_required_parts_only
    status, _, body = @app.call(method: "GET", path: "/bash/test")

    assert_equal 200, status
    assert_equal "#!/bin/bash\necho $B $D\n", body
  end

  def test_app_accepts_base36_choice_token
    status, _, body = @app.call(method: "GET", path: "/bash/test/z")

    assert_equal 200, status
    assert_equal "#!/bin/bash\necho A\nexport B=aaa\necho $B $D\n", body
  end

  def test_app_rejects_invalid_choice
    status, _, body = @app.call(method: "GET", path: "/bash/test/-")

    assert_equal 404, status
    assert_equal "not found\n", body
  end

  def test_preview_route_renders_html_preview
    status, headers, body = @app.call(method: "GET", path: "/preview/bash/test/3")

    assert_equal 200, status
    assert_equal "text/html; charset=utf-8", headers["Content-Type"]
    assert_includes body, "<h1>bash/test</h1>"
    assert_includes body, "<code>curl /bash/test/3</code>"
    assert_includes body, "<pre>#!/bin/bash"
  end

  def test_secured_app_rejects_missing_token
    status, headers, body = @secured_app.call(method: "GET", path: "/bash/test/3")

    assert_equal 401, status
    assert_equal ['Bearer', 'realm="snippetion"'].join(" "), headers["WWW-Authenticate"]
    assert_equal "unauthorized\n", body
  end

  def test_secured_app_accepts_query_token
    status, _, body = @secured_app.call(method: "GET", path: "/bash/test/3", query_string: "token=#{@access_token}")

    assert_equal 200, status
    assert_equal "#!/bin/bash\necho A\nexport B=aaa\necho $B $D\n", body
  end

  def test_secured_preview_keeps_token_in_fetch_urls
    status, _, body = @secured_app.call(method: "GET", path: "/preview/bash/test/3", query_string: "token=#{@access_token}")

    assert_equal 200, status
    assert_includes body, "/bash/test/3?token=#{@access_token}"
  end

  def test_secured_app_accepts_bearer_token
    status, _, body = @secured_app.call(
      method: "GET",
      path: "/bash/test/2",
      headers: { "authorization" => ["Bearer " + @access_token] }
    )

    assert_equal 200, status
    assert_equal "#!/bin/bash\nexport B=aaa\necho $B $D\n", body
  end

  def test_edit_route_renders_html_editor
    status, headers, body = @app.call(method: "GET", path: "/edit/bash/test")

    assert_equal 200, status
    assert_equal "text/html; charset=utf-8", headers["Content-Type"]
    assert_includes body, "<h1>bash/test</h1>"
    assert_includes body, "<textarea"
    assert_includes body, "<pre id=\"preview\">"
  end

  def test_edit_route_requires_auth_when_secured
    status, _, body = @secured_app.call(method: "GET", path: "/edit/bash/test")

    assert_equal 401, status
    assert_equal "unauthorized\n", body
  end

  def test_edit_route_accepts_token_and_embeds_it
    status, _, body = @secured_app.call(
      method: "GET",
      path: "/edit/bash/test",
      query_string: "token=#{@access_token}"
    )

    assert_equal 200, status
    assert_includes body, @access_token
  end

  def test_edit_route_returns_404_for_missing_project
    status, _, body = @app.call(method: "GET", path: "/edit/bash/nonexistent")

    assert_equal 404, status
    assert_equal "not found\n", body
  end

  def test_netrc_route_returns_entry_when_authorized
    status, headers, body = @secured_app.call(
      method: "GET",
      path: "/.netrc",
      query_string: "token=#{@access_token}&host=example.com&login=myuser"
    )

    assert_equal 200, status
    assert_equal "text/plain; charset=utf-8", headers["Content-Type"]
    assert_equal "machine example.com\nlogin myuser\npassword #{@access_token}\n", body
  end

  def test_netrc_route_defaults_host_and_login
    status, _, body = @secured_app.call(
      method: "GET",
      path: "/.netrc",
      query_string: "token=#{@access_token}"
    )

    assert_equal 200, status
    assert_includes body, "machine localhost\n"
    assert_includes body, "login token\n"
  end

  def test_netrc_route_rejects_wrong_token
    status, _, body = @secured_app.call(
      method: "GET",
      path: "/.netrc",
      query_string: "token=wrongtoken"
    )

    assert_equal 401, status
    assert_equal "unauthorized\n", body
  end

  def test_netrc_route_no_access_token_configured
    status, _, body = @app.call(method: "GET", path: "/.netrc")

    assert_equal 200, status
    assert_includes body, "# No ACCESS_TOKEN"
  end
end
