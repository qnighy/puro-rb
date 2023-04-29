# frozen_string_literal: true

require "uri"

module Puro
  module Http
    autoload :H1, "puro/http/h1"
    autoload :Syntax, "puro/http/syntax"

    HTTP_DEFAULT_PORT = 80
    HTTPS_DEFAULT_PORT = 443
  end
end
