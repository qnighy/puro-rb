# frozen_string_literal: true

# Puro is a WebSocket library that abstracts the connection as streams.
module Puro
  autoload :VERSION, "puro/version"
  autoload :IOAdapter, "puro/io_adapter"
  autoload :Http, "puro/http"
  autoload :MiddlewareChain, "puro/middleware"
  autoload :Middleware, "puro/middleware"
  autoload :BaseMiddleware, "puro/middleware"
  autoload :Client, "puro/client"
  autoload :WS, "puro/ws"

  class Error < StandardError; end
  # Your code goes here...
end
