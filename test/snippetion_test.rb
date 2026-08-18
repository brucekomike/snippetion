require "minitest/autorun"
require_relative "../lib/snippetion"

class SnippetionTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def setup
    @app = Snippetion::App.new(root: ROOT)
    @project = Snippetion::Project.load(root: ROOT, group: "bash", project: "test")
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

  def test_app_rejects_invalid_choice
    status, _, body = @app.call(method: "GET", path: "/bash/test/z")

    assert_equal 400, status
    assert_match(/invalid choice character/, body)
  end
end
