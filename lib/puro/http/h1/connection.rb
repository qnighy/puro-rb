# frozen_string_literal: true

require "puro/http/h1/connection_impl"
require "puro/http/h1/stream"

module Puro
  module Http
    module H1
      # An HTTP/1.1 connection.
      # HTTP/1.1 allows sending multiple requests in order
      # in a single connection (keep-alive).
      # We call each request-response a "stream" to be
      # in line with HTTP/2 and HTTP/3.
      class Connection
        def initialize(io)
          @impl = ConnectionImpl.new(io)
          @last_id = 0
        end

        def open_stream
          id = (@last_id += 1)
          Stream.new(@impl, id)
        end
      end
    end
  end
end
