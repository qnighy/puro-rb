# frozen_string_literal: true

require "uri"

module Puro
  module Http
    autoload :H1, "puro/http/h1"
    autoload :Syntax, "puro/http/syntax"

    HTTP_DEFAULT_PORT = 80
    HTTPS_DEFAULT_PORT = 443

    def self.request(method, url, middlewares:)
      uri = URI.parse(url)
      hostname = uri.hostname || raise("Missing hostname: #{url}")
      chain = MiddlewareChain.build(middlewares)
      conn = case uri.scheme
             when "http"
               chain.connect_http(chain, hostname, uri.port || HTTP_DEFAULT_PORT)
             when "https"
               chain.connect_https(chain, hostname, uri.port || HTTPS_DEFAULT_PORT)
             else
               raise "Invalid scheme #{uri.scheme}: #{url}"
             end
      stream = conn.open_stream
      stream.write_headers(
        {
          ":method" => method.to_s,
          ":path" => uri.path.empty? ? "/" : uri.path,
          "host" => hostname,
          "user-agent" => "test",
          "accept" => "text/html"
        }
      )
      stream.flush

      headers = stream.read_headers
      status = headers.delete(":status").to_i

      content = stream.reader.read
      conn.close

      [status, headers, content]
    end
  end
end
