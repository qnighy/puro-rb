# frozen_string_literal: true

require "uri"
require "socket"
require "openssl"

module Puro
  module Http
    autoload :H1, "puro/http/h1"
    autoload :Syntax, "puro/http/syntax"

    def self.request(middlewares:)
      chain = MiddlewareChain.build(middlewares)
      conn = chain.connect_http(chain, "example.com", 80)
      stream = conn.open_stream
      stream.write_headers(
        {
          ":method" => "GET",
          ":path" => "/",
          "host" => "example.com",
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
