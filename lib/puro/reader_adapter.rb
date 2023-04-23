# frozen_string_literal: true

require "English"

module Puro
  module ReaderAdapter
    # :nodoc:
    PARTIAL_LEN = 4096

    def readline(*args, chomp: false)
      sep, limit = ReaderAdapter.getline_args(args)
      raise "TODO: limit arg" if limit >= 0

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
      line = buf[0, pos]
      ungetbyte(buf[pos..]) if pos < buf.size
      line
    end

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
