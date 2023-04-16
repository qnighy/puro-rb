# frozen_string_literal: true

module Puro
  module Http
    module Syntax
      # Strips CRLF from the line
      #
      # Reference:
      #
      # {https://datatracker.ietf.org/doc/html/rfc9112#name-message-format RFC9112§2.1}
      #
      # > An HTTP/1.1 message consists of a start-line followed by a CRLF and (...)
      #
      # {https://datatracker.ietf.org/doc/html/rfc9112#name-message-parsing RFC9112§2.2}
      #
      # > Although the line terminator for the start-line and fields is the
      # > sequence CRLF, a recipient MAY recognize a single LF as a line
      # > terminator and ignore any preceding CR.
      #
      def self.strip_line(line)
        raise "Incorrectly terminated line" unless line.end_with?("\r\n")

        line[0...-2]
      end

      # Parses HTTP/1.1 status line
      #
      # Reference:
      #
      # {https://datatracker.ietf.org/doc/html/rfc9112#name-status-line RFC9112§4}
      def self.parse_h1_status(line)
        m = RE_H1_STATUS.match(line)
        raise "Invalid status line" if m.nil?

        [m[1], m[2].to_i]
      end

      # :nodoc:
      # See {https://datatracker.ietf.org/doc/html/rfc9112#name-status-line RFC9112§4}
      # `HTTP` "HTTP-version is case-sensitive." (§2.3)
      # `(\d.\d)` one digit is sufficient according to the grammar
      # ` ` Denoted by SP in the grammar; recipients MAY instead parse `\s+` but we don't implement it here
      # `([1-5]\d{2})` this is defined as 3DIGIT in the grammar but RFC9110§15 defines their valid range
      # `[^\x00-\x08\x0A-\x1F\x7F]*` this is `[1*( HTAB / SP / VCHAR / obs-text )]`,
      #   which is equivalent to `*( HTAB / SP / VCHAR / obs-text )`,
      #   which is in turn %x09 / %x20 / %x21-7E / %x80-%FF
      #   the inversion of which is %x00-08 / %x0A-1F / %x7F
      # Also, we don't capture the reason phrase because:
      #   "A client SHOULD ignore the reason-phrase content because it is not a reliable channel for information"
      RE_H1_STATUS = %r{\AHTTP/(\d\.\d) ([1-5]\d{2}) [^\x00-\x08\x0A-\x1F\x7F]*\z}.freeze

      # :nodoc:
      RE_FIELD_NAME = /\A[!#$%&'*+\-.^_`|~0-9A-Za-z]+\z/.freeze

      # :nodoc:
      RE_FIELD_VALUE = /\A[^\x00-\x20\x7F]+\z/.freeze
    end
  end
end
