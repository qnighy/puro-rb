# frozen_string_literal: true

require "socket"

module Puro
  module Http
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

RSpec.describe "http" do
  def get
    sock = Socket.tcp("example.com", 80)
    sock << "GET / HTTP/1.1\r\nHost: example.com\r\nUser-Agent: test\r\nAccept: text/html\r\n\r\n"
    sock.close_write

    line = Puro::Http::Syntax.strip_line(sock.readline)
    _version, status = Puro::Http::Syntax.parse_h1_status(line)

    headers = {}
    Puro::Http::Syntax.parse_h1_fields(Puro::Http::LineReader.new(sock)) do |name, value|
      if name == "set-cookie"
        (headers[name] ||= []) << value
      elsif headers.key?(name)
        headers[name] << ", "
        headers[name] << value
      else
        headers[name] = value
      end
    end

    content = sock.read
    sock.close

    [status, headers, content]
  end
  describe "http" do
    it "requests an HTTP resource successfully" do
      status, headers, content = get
      expect(status).to be(200)
      expect(headers["content-type"]).to match(/^text\/html\b/)
      expect(content).to include("https://www.iana.org/domains/example")
    end
  end
end
