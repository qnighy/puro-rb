# frozen_string_literal: true

require "puro/middleware"
require "puro/http"

module Puro
  class Client
    def initialize(
      connection_middlewares: [Puro::BaseMiddleware]
    )
      middlewares = [*connection_middlewares]
      @chain = Puro::MiddlewareChain.build(middlewares)
    end

    def request(method, url)
      uri = URI.parse(url)
      hostname = uri.hostname || raise("Missing hostname: #{url}")
      conn = case uri.scheme
             when "http"
               @chain.connect_http(@chain, hostname, uri.port || Puro::Http::HTTP_DEFAULT_PORT)
             when "https"
               @chain.connect_https(@chain, hostname, uri.port || Puro::Http::HTTPS_DEFAULT_PORT)
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
