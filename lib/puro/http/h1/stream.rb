# frozen_string_literal: true

module Puro
  module Http
    module H1
      class Stream
        def initialize(io)
          @io = io
        end

        def read_headers
          status_line = Puro::Http::Syntax.strip_line(@io.readline)
          version, status = Puro::Http::Syntax.parse_h1_status(status_line)
          @server_version = version
          @status = status

          headers = { ":status" => status }
          Puro::Http::Syntax.parse_h1_fields(Puro::Http::H1::LineReader.new(@io)) do |name, value|
            if name == "set-cookie"
              (headers[name] ||= []) << value
            elsif headers.key?(name)
              headers[name] << ", "
              headers[name] << value
            else
              headers[name] = value
            end
          end

          headers
        end
      end
    end
  end
end
