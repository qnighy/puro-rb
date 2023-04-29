# frozen_string_literal: true

require "puro/middleware"

class SockMockMiddleware
  include Puro::Middleware

  def initialize
    @resps = []
  end

  def stub_tcp(hostname, port, &block)
    @resps << Responder.new(proto: :tcp, hostname: hostname, port: port, &block)
    nil
  end

  def stub_tls(hostname, port, &block)
    @resps << Responder.new(proto: :tls, hostname: hostname, port: port, &block)
    nil
  end

  def connect_tcp(_root, _nxt, hostname, port, **)
    resp = @resps.find { |r| r.active?(proto: :tcp, hostname: hostname, port: port) }
    raise "No match to connect_tcp(#{hostname.inspect}, #{port.inspect})" unless resp

    resp.connect(proto: :tcp, hostname: hostname, port: port)
  end

  def connect_tls(_root, _nxt, hostname, port, **)
    resp = @resps.find { |r| r.active?(proto: :tls, hostname: hostname, port: port) }
    raise "No match to connect_tls(#{hostname.inspect}, #{port.inspect})" unless resp

    resp.connect(proto: :tls, hostname: hostname, port: port)
  end

  class Responder
    attr_reader :times_used

    def initialize(proto:, hostname:, port:, &block)
      @proto = proto
      @hostname = hostname
      @port = port
      @times_used = 0
      @block = block
    end

    def active?(proto:, hostname:, port:)
      @proto === proto && @hostname === hostname && @port === port && @times_used < 1 # rubocop:disable Style/CaseEquality
    end

    def connect(proto:, hostname:, port:) # rubocop:disable Lint/UnusedMethodArgument
      @times_used += 1
      @block.call
    end
  end
end
