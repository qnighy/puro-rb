# frozen_string_literal: true

require "socket"
require "openssl"

module Puro
  class MiddlewareChain
    def initialize(nxt, middleware)
      @next = nxt
      @middleware = middleware
    end

    def self.build(middlewares)
      chain = nil
      middlewares.reverse_each do |m|
        chain = MiddlewareChain.new(chain, m)
      end
      chain
    end

    def connect_http(root, hostname, port, **options)
      @middleware.connect_http(root, @next, hostname, port, **options)
    end

    def connect_https(root, hostname, port, **options)
      @middleware.connect_https(root, @next, hostname, port, **options)
    end

    def connect_tcp(root, hostname, port, **options)
      @middleware.connect_tcp(root, @next, hostname, port, **options)
    end

    def connect_tls(root, hostname, port, **options)
      @middleware.connect_tls(root, @next, hostname, port, **options)
    end
  end

  module Middleware
    def connect_http(root, nxt, hostname, port, **options)
      nxt.connect_http(root, hostname, port, **options)
    end

    def connect_https(root, nxt, hostname, port, **options)
      nxt.connect_https(root, hostname, port, **options)
    end

    def connect_tcp(root, nxt, hostname, port, **options)
      nxt.connect_tcp(root, hostname, port, **options)
    end

    def connect_tls(root, nxt, hostname, port, **options)
      nxt.connect_tls(root, hostname, port, **options)
    end
  end

  module BaseMiddleware
    class << self
      include Middleware

      def connect_http(root, _nxt, hostname, port, **options)
        sock = root.connect_tcp(root, hostname, port, **options)
        Puro::Http::H1::Connection.new(sock)
      end

      def connect_https(root, _nxt, hostname, port, **options)
        sock = root.connect_tls(root, hostname, port, **options)
        Puro::Http::H1::Connection.new(sock)
      end

      def connect_tcp(_root, _nxt, hostname, port, **_options)
        Socket.tcp(hostname, port)
      end

      def connect_tls(root, _nxt, hostname, port, **options)
        tcp_sock = root.connect_tcp(root, hostname, port, **options)
        sock = OpenSSL::SSL::SSLSocket.new(tcp_sock)
        sock.sync_close = true
        tcp_sock = nil
        sock.hostname = hostname
        sock.connect
        sock.post_connection_check(hostname)
        sock.tap do
          sock = nil
        end
      ensure
        tcp_sock&.close
        sock&.close
      end
    end
  end
end
