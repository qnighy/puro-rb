# frozen_string_literal: true

module Puro
  module WS
    class Error < StandardError; end

    class InvalidURIError < Error; end
    class ConnectionError < Error; end
  end
end
