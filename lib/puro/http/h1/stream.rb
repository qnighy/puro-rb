# frozen_string_literal: true

require "puro/reader_adapter"

module Puro
  module Http
    module H1
      class Stream
        attr_reader :reader

        def initialize(io)
          @io = io
          @write_state = :header
          @read_state = :header
          @reader = BodyReader.new(self)
        end

        def write_headers(headers)
          raise ArgumentError, "Invalid state: #{@write_state}" unless @write_state == :header

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
          @write_state = :fin
          nil
        end

        def read_headers
          raise ArgumentError, "Invalid state: #{@read_state}" unless @read_state == :header

          status_line = Puro::Http::Syntax.strip_line(@io.readline)
          version, status = Puro::Http::Syntax.parse_h1_status(status_line)
          @server_version = version
          @status = status

          headers = { ":status" => status.to_s }
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

          transfer_encoding = headers.delete("transfer-encoding")
          content_length = headers["content-length"]
          if status < 200
            # continue with the current state
          elsif status == 200 && false # method == CONNECT
            raise "TODO: handle CONNECT case"
          elsif [204, 304].include?(status)
            @read_state = :length_delimited
            @read_length = 0
            @read_pos = 0
          elsif transfer_encoding
            headers.delete("content-length") if content_length
            encodings = Syntax.split(transfer_encoding)
            @read_state = encodings[-1] == "chunked" ? :chunked : :indefinite
          elsif content_length
            raise "Invalid Content-Length: #{content_length}" unless /\A(0|[1-9][0-9]*)\z/.match?(content_length)

            @read_state = :length_delimited
            @read_length = content_length.to_i
            @read_pos = 0
          else
            @read_state = :indefinite
          end
          raise "TODO: chunked" if @read_state == :chunked

          headers
        end

        # :nodoc:
        def readpartial_body(maxlen, outbuf)
          case @read_state
          when :length_delimited
            tmaxlen = [maxlen, @read_length - @read_pos].min
            @io.readpartial(tmaxlen, outbuf).tap do |result|
              raise EOFError if result == "" && maxlen > 0
            end
          when :chunked
            raise "TODO: chunked"
          when :indefinite
            @io.readpartial(maxlen, outbuf)
          else
            raise ArgumentError, "Invalid read on state #{@read_state}"
          end
        end

        # :nodoc:
        class BodyReader
          include ReaderAdapter

          def initialize(stream)
            @stream = stream
          end

          def readpartial(maxlen, outbuf = +"")
            @stream.readpartial_body(maxlen, outbuf)
          end

          def internal_encoding = nil
          def external_encoding = Encoding::ASCII_8BIT
        end
      end
    end
  end
end
