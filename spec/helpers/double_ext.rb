# frozen_string_literal: true

require "rspec/mocks"

module RSpec
  module Mocks
    class MessageExpectation
      def and_return_or_raise(first_value, *values)
        raise_already_invoked_error_if_necessary(__method__)
        raise "`and_return` is not supported with negative message expectations" if negative?

        raise ArgumentError, "Implementation blocks aren't supported with `and_return`" if block_given?

        values.unshift(first_value)
        unless ignoring_args? || (@expected_received_count == 0 && @at_least)
          @expected_received_count = [@expected_received_count, values.size].max
        end
        self.terminal_implementation_action = AndReturnOrRaiseImplementation.new(values)

        nil
      end
    end

    class AndReturnOrRaiseImplementation < AndReturnImplementation
      def call(*_args_to_ignore, &_block)
        super.tap do |value|
          raise(value) if value.is_a?(Exception) || (value.is_a?(Class) && value < Exception)
        end
      end
    end
  end
end
