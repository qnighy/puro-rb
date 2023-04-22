# frozen_string_literal: true

module Puro
  module Http
    module H1
      class Stream
        def initialize(io)
          @io = io
        end

        def write_headers(headers)
          method = headers[":method"] || raise("Missing :method")
          path = headers[":path"] || raise("Missing :path")
          host = headers["host"]

          @io << "#{method} #{path} HTTP/1.1\r\n"
          @io << "host: #{host}\r\n" if host
          headers.each do |name, value|
            next if name.start_with?(":") || name == "host"

            @io << "#{name}: #{value}\r\n"
          end
          @io << "\r\n"
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
