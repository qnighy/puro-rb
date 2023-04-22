# frozen_string_literal: true

module Puro
  module Http
    module H1
      class LineReader
        include Enumerable
        def initialize(io)
          @io = io
        end

        def each(&block)
          loop do
            line = Puro::Http::Syntax.strip_line(@io.readline)
            break if line.empty?

            block.call(line)
          end
          nil
        end
      end
    end
  end
end

