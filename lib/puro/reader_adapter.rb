# frozen_string_literal: true

require "English"

module Puro
  module ReaderAdapter
    # :nodoc:
    PARTIAL_LEN = 4096

    def read(maxlen = nil, outbuf = +"".b)
      if maxlen.nil?
        # Text mode
        outbuf.clear
        outbuf.force_encoding(Encoding::ASCII_8BIT)
        inbuf = nil
        begin
          outbuf = readpartial(PARTIAL_LEN, outbuf)
          loop do
            outbuf << readpartial(PARTIAL_LEN, inbuf ||= +"".b)
          end
        rescue EOFError
          return nil if outbuf.empty?
          # continue otherwise
        end
        ReaderAdapter.decode(self, outbuf)
      else
        # Binary mode
        outbuf.clear
        inbuf = nil
        begin
          outbuf = readpartial(maxlen, outbuf)
          while outbuf.bytesize < maxlen
            outbuf << readpartial(maxlen - outbuf.size, inbuf ||= +"".b)
          end
        rescue EOFError
          return nil if outbuf.empty? && maxlen > 0
          # continue otherwise
        end
        outbuf
      end
    end

    def readline(*args, chomp: false)
      sep, limit = ReaderAdapter.getline_args(args)
      raise "TODO: limit arg" if limit >= 0
      raise "TODO: chomp" if chomp

      last = 0
      buf = readpartial(PARTIAL_LEN)
      pos0 = buf.byteindex(sep, last)
      until pos0
        last = buf.bytesize
        last = [last - sep.size + 1, 0].max if sep.size > 1
        buf << readpartial(PARTIAL_LEN)
        pos0 = buf.byteindex(sep, last)
      end
      pos = pos0 + sep.bytesize
      ungetbyte(buf[pos..]) if pos < buf.size
      ReaderAdapter.decode(self, buf[0, pos])
    end

    # :nodoc:
    def self.decode(io, text)
      external_encoding = io.external_encoding || Encoding.default_external
      internal_encoding = io.internal_encoding || Encoding.default_internal
      text.force_encoding(external_encoding)
      text.encode!(internal_encoding) if internal_encoding
      text
    end

    # :nodoc:
    def self.getline_args(args)
      case args.size
      when 0
        [$RS, -1]
      when 1
        if args[0].nil?
          [nil, -1]
        elsif (tmp = args[0].try(:to_str))
          [tmp, -1]
        else
          raise TypeError unless args[0].is_a?(Integer)

          [$RS, args[0]]
        end
      when 2
        raise TypeError unless args[1].is_a?(Integer)

        [args[0]&.to_str, args[1]]
      else
        raise ArgumentError, "Too many arguments"
      end
    end
  end
end
