# frozen_string_literal: true

require "puro/io_adapter"

module Puro
  module Http
    module H1
      class ConnectionImpl
        def initialize(io)
          @io = io
          @write_state = :header
          @read_state = :header
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

        def flush
          @io.flush
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

          # {https://datatracker.ietf.org/doc/html/rfc9112#name-message-body-length RFC9112 §6.3}
          # Remove Transfer-Encoding as it is connection-specific
          transfer_encoding = headers.delete("transfer-encoding")
          # Keep Content-Length as it describes the content itself
          content_length = headers["content-length"]
          if status < 200
            # {https://datatracker.ietf.org/doc/html/rfc9110#section-15-7 RFC9110 §15}
            # > A single request can have multiple associated responses: zero or more
            # > "interim" (non-final) responses with status codes in the
            # > "informational" (1xx) range, followed by exactly one "final" response
            # > with a status code in one of the other ranges.
            #
            # According to the paragraph above, 1xx implies another set of headers.
            # Continuing with the current state.
          elsif (200..299).cover?(status) && false # rubocop:disable Lint/LiteralAsCondition -- method == CONNECT
            # {https://datatracker.ietf.org/doc/html/rfc9112#section-6.3-2.2 RFC9112 §6.3}
            # > Any 2xx (Successful) response to a CONNECT request implies that
            # > the connection will become a tunnel immediately after the empty
            # > line that concludes the header fields. A client MUST ignore any
            # > Content-Length or Transfer-Encoding header fields received in
            # > such a message.
            raise "TODO: handle CONNECT case"
          elsif [204, 304].include?(status)
            # {https://datatracker.ietf.org/doc/html/rfc9112#section-6.3-2.1 RFC9112 §6.3}
            # > Any response to a HEAD request and any response with a 1xx
            # > (Informational), 204 (No Content), or 304 (Not Modified) status
            # > code is always terminated by the first empty line after the
            # > header fields, regardless of the header fields present in the
            # > message, and thus cannot contain a message body or trailer
            # > section.
            #
            # And also {https://datatracker.ietf.org/doc/html/rfc9110#section-6.4.1-8 RFC9110 §6.4.1}
            # > All 1xx (Informational), 204 (No Content), and 304 (Not Modified)
            # > responses do not include content.
            # >
            # > All other responses do include content, although that content might
            # > be of zero length.
            # .
            # So they are regarded as "no content" rather than "zero-length content"
            @read_state = :fin
          elsif transfer_encoding
            # {https://datatracker.ietf.org/doc/html/rfc9112#section-6.3-2.3 RFC9112 §6.3}
            # > If a message is received with both a Transfer-Encoding and a
            # > Content-Length header field, the Transfer-Encoding overrides the
            # > Content-Length. Such a message might indicate an attempt to
            # > perform request smuggling (Section 11.2) or response splitting
            # > (Section 11.1) and ought to be handled as an error. An
            # > intermediary that chooses to forward the message MUST first
            # > remove the received Content-Length field and process the
            # > Transfer-Encoding (as described below) prior to forwarding the
            # > message downstream.
            # This implies that such requests should semantically lack Content-Length.
            headers.delete("content-length") if content_length
            # {https://datatracker.ietf.org/doc/html/rfc9112#section-6.3-2.4.1 RFC9112 §6.3}
            # > If a Transfer-Encoding header field is present and the chunked
            # > transfer coding (Section 7.1) is the final encoding, the message
            # > body length is determined by reading and decoding the chunked
            # > data until the transfer coding indicates the data is complete.
            #
            # And also {https://datatracker.ietf.org/doc/html/rfc9112#section-6.3-2.4.2 RFC9112 §6.3}
            # > If a Transfer-Encoding header field is present in a response and
            # > the chunked transfer coding is not the final encoding, the
            # > message body length is determined by reading the connection
            # > until it is closed by the server.
            encodings = Syntax.split(transfer_encoding)
            @read_state = encodings[-1] == "chunked" ? :chunked : :indefinite
          elsif content_length
            # {https://datatracker.ietf.org/doc/html/rfc9112#section-6.3-2.5 RFC9112 §6.3}
            # > If a message is received without Transfer-Encoding and with an
            # > invalid Content-Length header field, then the message framing is
            # > invalid and the recipient MUST treat it as an unrecoverable
            # > error, unless (...)
            # Regarding to the exception above,
            # {https://datatracker.ietf.org/doc/html/rfc9110#section-8.6-13 RFC9110 §8.6}:
            # > a recipient of a Content-Length header field value
            # > consisting of the same decimal value repeated as a comma-separated
            # > list (e.g, "Content-Length: 42, 42") MAY either reject the message as
            # > invalid or replace that invalid field value with a single instance of
            # > the decimal value, since (...)
            # So we choose not to handle these exceptions.
            # In case of syntax error, {https://datatracker.ietf.org/doc/html/rfc9112#section-6.3-2.5 RFC9112 §6.3}
            # > If it is in a
            # > response message received by a user agent, the user agent MUST
            # > close the connection to the server and discard the received
            # > response.
            raise "Invalid Content-Length: #{content_length}" unless /\A(0|[1-9][0-9]*)\z/.match?(content_length)

            # {https://datatracker.ietf.org/doc/html/rfc9112#section-6.3-2.6 RFC9112§6.3}
            # > If a valid Content-Length header field is present without
            # > Transfer-Encoding, its decimal value defines the expected
            # > message body length in octets.
            @read_state = :length_delimited
            @read_length = content_length.to_i
            @read_pos = 0
          else
            # {https://datatracker.ietf.org/doc/html/rfc9112#section-6.3-2.8 RFC9112§6.3}
            # > Otherwise, this is a response message without a declared message
            # > body length, so the message body length is determined by the
            # > number of octets received prior to the server closing the
            # > connection.
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
            if maxlen == 0
              outbuf.clear
              return outbuf
            elsif tmaxlen == 0
              raise EOFError
            end
            @io.readpartial(tmaxlen, outbuf).tap do |result|
              raise EOFError if result == "" && maxlen > 0

              @read_pos += result.bytesize
            end
          when :chunked
            raise "TODO: chunked"
          when :indefinite
            @io.readpartial(maxlen, outbuf)
          else
            raise ArgumentError, "Invalid read on state #{@read_state}"
          end
        end

        def close
          @io.close
        end
      end
    end
  end
end
