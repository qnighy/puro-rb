# frozen_string_literal: true

require "socket"

module Puro
  RE_STATUS_LINE = /\AHTTP\/\d\.\d ([1-5]\d{2}) /
  RE_FIELD_NAME = /\A[!#$%&'*+\-.^_`|~0-9A-Za-z]+\z/
  RE_FIELD_VALUE = /\A[^\x00-\x1F]+\z/
end

RSpec.describe "http" do
  def get
    sock = Socket.tcp("example.com", 80)
    sock << "GET / HTTP/1.1\r\nHost: example.com\r\nUser-Agent: test\r\nAccept: text/html\r\n\r\n"
    sock.close_write

    line = sock.readline
    status, * = (Puro::RE_STATUS_LINE.match(line) || raise("Invalid status line")).captures
    status = status.to_i

    headers = {};
    loop do
      line = sock.readline.sub(/\r\n\z/, "")
      break if line.empty?

      name, value = line.split(":", 2)
      if name.nil? || value.nil? || !Puro::RE_FIELD_NAME.match?(name) || !Puro::RE_FIELD_VALUE.match?(name)
        raise "Invalid header line"
      end
      value = value.strip
      name = name.downcase
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
