# frozen_string_literal: true

require "uri"
require "socket"
require "openssl"
require "websocket"

module Puro
  # Puro's WebSocket support.
  module WS
    # Opens the new WebSocket connection.
    def self.open(url, &block)
      url_parsed =
        begin
          URI.parse(url)
        rescue URI::InvalidURIError, URI::InvalidComponentError => e
          raise Puro::WS::InvalidURIError, e.message
        end
      default_port, secure =
        case url_parsed.scheme
        when "ws"
          [80, false]
        when "wss"
          [443, true]
        else
          raise Puro::WS::InvalidURIError, "Invalid URI scheme #{url_parsed.scheme}, expected ws or wss"
        end
      hostname = url_parsed.hostname
      port = url_parsed.port || default_port
      raise Puro::WS::InvalidURIError, "Missing host" if hostname.nil? || hostname == ""
      raise Puro::WS::InvalidURIError, "Unexpected userinfo in the URL" if url_parsed.userinfo
      raise Puro::WS::InvalidURIError, "Unexpected fragment in the URL" if url_parsed.fragment

      socket =
        begin
          Socket.tcp(url_parsed.hostname, port)
        rescue SocketError => e
          raise Puro::WS::ConnectionError, e.message
        end
      if secure
        begin
          socket = OpenSSL::SSL::SSLSocket.new(socket)
          socket.sync_close = true
          socket.hostname = url_parsed.hostname
          socket.connect
        rescue OpenSSL::SSL::SSLError => e
          raise Puro::WS::ConnectionError, e.message
        end
      end

      conn = Puro::WS::Connection.new(socket: socket, url: url)
      conn.connect
      socket = nil
      if block
        block.call(conn)
      else
        conn.tap { conn = nil }
      end
    ensure
      conn&.close
      socket&.close
    end

    class Connection
      BUF_LEN = 1024
      def initialize(socket:, url:)
        @socket = socket
        @url = url
      end

      def connect
        @handshake = WebSocket::Handshake::Client.new(url: @url)
        @socket << @handshake.to_s
        @socket.flush
      end

      def next
        loop do
          frame = next_frame
          case frame.type
          when :data
            return frame.data.b
          when :text
            return frame.to_s
          when :ping
            @socket << WebSocket::Frame::Outgoing::Client.new(type: :pong, data: frame.data).to_s
            @socket.flush
          when :pong
            raise "TODO: pong"
          when :close
            raise "TODO: close"
          end
        end
      end

      def push(msg, type: :text)
        @socket << WebSocket::Frame::Outgoing::Client.new(type: type, data: msg)
        @socket.flush
      end

      def <<(msg)
        push(msg)
      end

      def close
        @socket.close
      end

      private

      def next_frame
        receive_one while @handshake
        loop do
          frame = @frame.next
          return frame if frame

          receive_one
        end
      end

      def receive_one
        if @handshake
          @handshake << @socket.read(BUF_LEN)
          if @handshake.finished?
            unless @handshake.valid?
              raise "TODO: handshake failure"
            end
            @frame = WebSocket::Frame::Incoming::Client.new(version: @handshake.version)
            @frame << @handshake.leftovers
            @handshake = nil
          end
        elsif @frame
          @frame << @socket.read(BUF_LEN)
          if @frame.error?
            raise "TODO: frame error"
          end
        else
          raise ArgumentError, "Not connected yet"
        end
      end
    end
  end
end
