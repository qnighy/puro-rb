# frozen_string_literal: true

require_relative "puro/version"
require_relative "puro/reader_adapter"
require_relative "puro/http/syntax"
require_relative "puro/http/h1/line_reader"
require_relative "puro/http/h1/connection_impl"
require_relative "puro/ws"

# Puro is a WebSocket library that abstracts the connection as streams.
module Puro
  class Error < StandardError; end
  # Your code goes here...
end
