# frozen_string_literal: true

require "puro/reader_adapter"
require "puro/http/h1/connection_impl"

module Puro
  module Http
    module H1
      # A virtual "stream" used to send one request
      # in an HTTP/1.1 connection.
      class Stream
        attr_reader :reader

        # :nodoc:
        def initialize(impl, id)
          @impl = impl
          @id = id
          @reader = BodyReader.new(@impl, id)
        end

        def write_headers(headers)
          @impl.write_headers(headers)
        end

        def read_headers
          @impl.read_headers
        end

        # :nodoc:
        class BodyReader
          include ReaderAdapter

          def initialize(impl, id)
            @impl = impl
            @id = id
          end

          def readpartial(maxlen, outbuf = +"")
            @impl.readpartial_body(maxlen, outbuf)
          end

          def internal_encoding = nil
          def external_encoding = Encoding::ASCII_8BIT
        end
      end
    end
  end
end
