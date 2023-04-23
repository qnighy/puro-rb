# frozen_string_literal: true

require "socket"
require_relative "./helpers/stream_mock"

RSpec.describe "http" do
  def get
    get_sock(Socket.tcp("example.com", 80))
  end

  def get_sock(sock)
    stream = Puro::Http::H1::Stream.new(sock)
    stream.write_headers(
      {
        ":method" => "GET",
        ":path" => "/",
        "host" => "example.com",
        "user-agent" => "test",
        "accept" => "text/html"
      }
    )
    sock.close_write

    headers = stream.read_headers
    status = headers.delete(":status").to_i

    content = stream.reader.read
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
          [:read, "host: example.com\r\n"],
          [:read, "user-agent: test\r\n"],
          [:read, "accept: text/html\r\n"],
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
