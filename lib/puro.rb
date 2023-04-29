# frozen_string_literal: true

# Puro is a WebSocket library that abstracts the connection as streams.
module Puro
  autoload :VERSION, "puro/version"
  autoload :ReaderAdapter, "puro/reader_adapter"
  autoload :Http, "puro/http"
  autoload :WS, "puro/ws"

  class Error < StandardError; end
  # Your code goes here...
end
