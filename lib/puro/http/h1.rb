# frozen_string_literal: true

module Puro
  module Http
    module H1
      autoload :Connection, "puro/http/h1/connection"
      autoload :ConnectionImpl, "puro/http/h1/connection_impl"
      autoload :LineReader, "puro/http/h1/line_reader"
      autoload :Stream, "puro/http/h1/stream"
    end
  end
end
