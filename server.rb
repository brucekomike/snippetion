require "webrick"
require_relative "lib/snippetion"

root = File.expand_path(__dir__)
app = Snippetion::App.new(root: root)

server = WEBrick::HTTPServer.new(Port: ENV.fetch("PORT", "9292").to_i)

server.mount_proc("/") do |request, response|
  normalized_headers = request.header.transform_values { |values| Array(values) }
  status, headers, body = app.call(
    method: request.request_method,
    path: request.path,
    query_string: request.query_string,
    headers: normalized_headers
  )
  response.status = status
  headers.each { |key, value| response[key] = value }
  response.body = body
end

trap("INT") { server.shutdown }

server.start
