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

      def self.split(text)
        text.split(",").map do |elem|
          elem = elem.strip
          elem = nil if elem == ""
          elem
        end.compact
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
      #
      # :nodoc:
      RE_H1_STATUS = %r{\AHTTP/(\d\.\d) ([1-5]\d{2}) [^\x00-\x08\x0A-\x1F\x7F]*\z}.freeze

      # Parses HTTP/1.1 field line
      #
      # Reference:
      #
      # {https://datatracker.ietf.org/doc/html/rfc9112#name-field-syntax RFC9112§5}
      def self.parse_h1_field(line)
        name, value = line.split(":", 2)
        # value is nil -> it is empty (len=0) or it has no colon (len=1)
        raise "Invalid header line" if value.nil? || !RE_H1_FIELD_NAME.match?(name) || !RE_H1_FIELD_VALUE.match?(value)

        # From §5: "Each field line consists of a case-insensitive field name followed by ..."
        name = name.downcase
        # From §5.1: "A field line value might be preceded and/or followed by optional whitespace (OWS)"
        # String#strip removes [\0\t\n\v\f\r ] but only [\t ] may appear here
        value = value.strip
        [name, value]
      end

      # {https://datatracker.ietf.org/doc/html/rfc9110#name-field-names RFC9110§5.1}
      #
      # > field-name     = token"
      #
      # {https://datatracker.ietf.org/doc/html/rfc9110#section-5.6.2 RFC9110§5.6.1}
      #
      # > token          = 1*tchar
      # > tchar          = "!" / "#" / "$" / "%" / "&" / "'" / "*"
      # >                / "+" / "-" / "." / "^" / "_" / "`" / "|" / "~"
      # >                / DIGIT / ALPHA
      # >                ; any VCHAR, except delimiters
      #
      # :nodoc:
      RE_H1_FIELD_NAME = /\A[!#$%&'*+\-.^_`|~0-9A-Za-z]+\z/.freeze

      # {https://datatracker.ietf.org/doc/html/rfc9110#name-field-values RFC9110§5.5}
      #
      # > field-value    = *field-content
      # > field-content  = field-vchar
      # >                  [ 1*( SP / HTAB / field-vchar ) field-vchar ]
      # > field-vchar    = VCHAR / obs-text
      # > obs-text       = %x80-FF
      #
      # But I suppose the two repetition operators are mutually redundant, no?
      # Like "text/html" being able to be interpreted as ["text/html"] or ["text", "/html"] or whatever.
      # Let's assume field-value = [field-content] and field-content = field-vchar [*(SP/HTAB/field-vchar) field-vchar].
      # (these are the same in terms of the language it generates)
      #
      # Then this essentially means *( SP / HTAB / field-vchar ) without leading or trailing ( SP / HTAB ).
      # .
      # In HTTP/1.1, the field is surrounded by arbitrary number of ( SP / HTAB ) so let's parse the whole part
      # and strip the leading and trailing whitespaces later.
      #
      # :nodoc:
      RE_H1_FIELD_VALUE = /\A[^\x00-\x08\x0A-\x1F\x7F]*\z/.freeze

      # Parses a list of HTTP/1.1 header lines.
      # This is like parse_h1_field but takes into account deprecated line folding in headers.
      #
      # {https://datatracker.ietf.org/doc/html/rfc9112#name-obsolete-line-folding RFC9112§5.2}
      # > Historically, HTTP/1.x field values could be extended over multiple
      # > lines by preceding each extra line with at least one space or
      # > horizontal tab (obs-fold).
      def self.parse_h1_fields(lines, &block)
        last_kv = nil
        lines.each do |line|
          if last_kv && (m_cont = RE_H1_FIELD_CONT.match(line))
            # Check correctness as in parse_h1_field
            raise "Invalid header line" unless RE_H1_FIELD_VALUE.match?(m_cont[1])

            # > A user agent that receives an obs-fold in a response message that is
            # > not within a "message/http" container MUST replace each received obs-
            # > fold with one or more SP octets prior to interpreting the field
            # > value.
            #
            # As described in the quote above, "one or more" spaces are fine.
            # Therefore we insert one SP per line continuation
            last_kv[1] << " ".b
            # Strip the value as in parse_h1_field
            last_kv[1] << m_cont[1].strip
          else
            block.call(*last_kv) if last_kv
            last_kv = parse_h1_field(line)
          end
        end
        block.call(*last_kv) if last_kv
        nil
      end

      # {https://datatracker.ietf.org/doc/html/rfc9112#name-obsolete-line-folding RFC9112§5.2}
      # `obs-fold = OWS CRLF RWS`
      # means that a continuation line is a line indented by /[\t ]+/.
      # The text after the indentation constitutes a part of the last field being processed.
      # This regex does not check the value's correctness; that would be done in parse_h1_fields
      #
      # :nodoc:
      RE_H1_FIELD_CONT = /\A[\t ]+(.*)\z/.freeze
    end
  end
end
