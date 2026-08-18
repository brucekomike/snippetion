require "cgi"
require "uri"

module Snippetion
  class Error < StandardError; end
  class InvalidChoice < Error; end
  class ProjectNotFound < Error; end
  class ParseError < Error; end

  Part = Struct.new(:name, :required, :body, keyword_init: true)

  module Choice
    ALPHABET = "0123456789abcdefghijklmnopqrstuvwxyz".freeze
    INDEX = ALPHABET.chars.each_with_index.to_h.freeze

    module_function

    def decode(value)
      normalized = value.to_s.downcase
      raise InvalidChoice, "choice cannot be empty" if normalized.empty?

      normalized.each_char.reduce(0) do |total, char|
        digit = INDEX[char]
        raise InvalidChoice, "invalid choice character: #{char}" unless digit

        (total * ALPHABET.length) + digit
      end
    end
  end

  class Project
    PART_HEADER = /\A```\s*([^\s`]+)\s+(must|opt)\s*\z/.freeze
    PART_FOOTER = /\A```\s*\z/.freeze
    SEGMENT_NAME = /\A[a-z0-9_-]+\z/.freeze

    attr_reader :parts

    def self.load(root:, group:, project:)
      unless SEGMENT_NAME.match?(group) && SEGMENT_NAME.match?(project)
        raise ProjectNotFound, "project not found"
      end

      path = File.join(root, "projects", group, "#{project}.snippet")
      raise ProjectNotFound, "project not found" unless File.file?(path)

      new(File.read(path))
    end

    def initialize(source)
      @parts = parse(source)
    end

    def optional_parts
      parts.reject(&:required)
    end

    def render(choice)
      selected_value = Choice.decode(choice)
      optional_index = 0

      rendered = parts.filter_map do |part|
        next part.body if part.required

        body = part.body if ((selected_value >> optional_index) & 1) == 1
        optional_index += 1
        body
      end

      return "" if rendered.empty?

      rendered.map { |body| body.sub(/\n\z/, "") }.join("\n") + "\n"
    end

    private

    def parse(source)
      parts = []
      current_name = nil
      current_required = nil
      current_body = []

      source.each_line do |line|
        if current_name.nil?
          header = PART_HEADER.match(line.chomp)
          next unless header

          current_name = header[1]
          current_required = header[2] == "must"
          current_body = []
          next
        end

        if PART_FOOTER.match?(line.chomp)
          parts << Part.new(name: current_name, required: current_required, body: current_body.join)
          current_name = nil
          current_required = nil
          current_body = []
        else
          current_body << line
        end
      end

      raise ParseError, "unterminated snippet part" if current_name
      raise ParseError, "project must define at least one part" if parts.empty?

      parts
    end
  end

  class App
    ROUTE = %r{\A/([a-z0-9_-]+)/([a-z0-9_-]+)(?:/([a-z0-9]+))?\z}.freeze
    PREVIEW_ROUTE = %r{\A/preview/([a-z0-9_-]+)/([a-z0-9_-]+)(?:/([a-z0-9]+))?\z}.freeze

    def initialize(root:, access_token: ENV["ACCESS_TOKEN"])
      @root = root
      @access_token = access_token
    end

    def call(method:, path:, query_string: nil, headers: {})
      return response(405, "method not allowed\n") unless method == "GET"
      return response(200, "request /<group>/<project>/<choice> or /preview/<group>/<project>/<choice>\n") if path == "/"

      params = parse_query(query_string)
      return unauthorized_response unless authorized?(params, headers)

      preview_match = PREVIEW_ROUTE.match(path)
      if preview_match
        group, project, choice = preview_match.captures
        return preview_response(group:, project:, choice: choice || "0", params:)
      end

      match = ROUTE.match(path)
      return response(404, "not found\n") unless match

      group, project, choice = match.captures
      body = Project.load(root: @root, group: group, project: project).render(choice || "0")
      response(200, body)
    rescue InvalidChoice => e
      response(400, "#{e.message}\n")
    rescue ProjectNotFound
      response(404, "not found\n")
    rescue ParseError => e
      response(422, "#{e.message}\n")
    end

    private

    def authorized?(params, headers)
      return true if @access_token.to_s.empty?

      token = params["token"] || bearer_token(headers)
      token == @access_token
    end

    def bearer_token(headers)
      authorization = Array(headers["authorization"]).first || Array(headers["Authorization"]).first
      return unless authorization

      match = /\ABearer\s+(.+)\z/.match(authorization)
      match && match[1]
    end

    def parse_query(query_string)
      return {} if query_string.to_s.empty?

      URI.decode_www_form(query_string).each_with_object({}) do |(key, value), params|
        params[key] = value
      end
    end

    def preview_response(group:, project:, choice:, params:)
      rendered = Project.load(root: @root, group: group, project: project).render(choice)
      base_path = "/#{group}/#{project}/#{choice}"
      fetch_query = params["token"] ? "?token=#{CGI.escape(params["token"])}" : ""
      fetch_url = "#{base_path}#{fetch_query}"
      body = <<~HTML
        <!DOCTYPE html>
        <html lang="en">
          <head>
            <meta charset="utf-8">
            <title>Snippet Preview</title>
          </head>
          <body>
            <h1>#{escape_html("#{group}/#{project}")}</h1>
            <p>Choice token: <code>#{escape_html(choice)}</code></p>
            <p><code>curl #{escape_html(fetch_url)}</code></p>
            <p><code>wget -O - #{escape_html(fetch_url)}</code></p>
            <pre>#{escape_html(rendered)}</pre>
          </body>
        </html>
      HTML
      html_response(200, body)
    end

    def unauthorized_response
      build_response(401, "unauthorized\n", "text/plain; charset=utf-8", { "WWW-Authenticate" => "Bearer " + 'realm="snippetion"' })
    end

    def escape_html(value)
      CGI.escapeHTML(value)
    end

    def response(status, body)
      build_response(status, body, "text/plain; charset=utf-8")
    end

    def html_response(status, body)
      build_response(status, body, "text/html; charset=utf-8")
    end

    def build_response(status, body, content_type, extra_headers = {})
      [
        status,
        {
          "Content-Type" => content_type,
          "Content-Length" => body.bytesize.to_s
        }.merge(extra_headers),
        body
      ]
    end
  end
end
