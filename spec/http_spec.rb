# frozen_string_literal: true

require "socket"
require_relative "./helpers/stream_mock"

RSpec.describe "http" do
  def get
    get_sock(Socket.tcp("example.com", 80))
  end

  def get_sock(sock)
    sock << "GET / HTTP/1.1\r\nHost: example.com\r\nUser-Agent: test\r\nAccept: text/html\r\n\r\n"
    sock.close_write

    stream = Puro::Http::H1::Stream.new(sock)
    headers = stream.read_headers
    status = headers.delete(":status")

    content = sock.read
    sock.close

    [status, headers, content]
  end
  describe "http" do
    it "requests an HTTP resource successfully (real)" do
      status, headers, content = get
      expect(status).to be(200)
      expect(headers["content-type"]).to match(%r{^text/html\b})
      expect(content).to include("https://www.iana.org/domains/example")
    end

    it "requests an HTTP resource successfully (mocked)" do
      sock = StreamMock.new(
        [
          [:read, "GET / HTTP/1.1\r\n"],
          [:read, "Host: example.com\r\n"],
          [:read, "User-Agent: test\r\n"],
          [:read, "Accept: text/html\r\n"],
          [:read, "\r\n"],
          [:write, "HTTP/1.1 200 OK\r\n"],
          [:write, "Content-Type: text/html; charset=UTF-8\r\n"],
          [:write, "Content-Length: 13\r\n"],
          [:write, "\r\n"],
          [:write, "Hello, world!"],
          [:close]
        ]
      )
      status, headers, content = get_sock(sock)
      expect(status).to be(200)
      expect(headers["content-type"]).to match(%r{^text/html\b})
      expect(content).to include("Hello, world!")
    end
  end
end
