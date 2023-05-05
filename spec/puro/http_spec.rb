# frozen_string_literal: true

require_relative "../helpers/io_mock"
require_relative "../helpers/sock_mock_middleware"

RSpec.describe Puro::Http do
  around do |example|
    IOMock.with_iomock do
      example.run
    end
  end

  it "requests an HTTP resource successfully" do
    sock = IOMock.new(
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

    sock_mock = SockMockMiddleware.new
    sock_mock.stub_tcp("example.com", 80) { sock }

    client = Puro::Client.new(connection_middlewares: [sock_mock, Puro::BaseMiddleware])
    status, headers, content = client.request(
      :GET,
      "http://example.com"
    )
    expect(status).to be(200)
    expect(headers["content-type"]).to match(%r{^text/html\b})
    expect(content).to eq("Hello, world!")
  end

  it "requests an HTTPS resource successfully" do
    sock = IOMock.new(
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

    sock_mock = SockMockMiddleware.new
    sock_mock.stub_tls("example.com", 443) { sock }

    client = Puro::Client.new(connection_middlewares: [sock_mock, Puro::BaseMiddleware])
    status, headers, content = client.request(
      :GET,
      "https://example.com"
    )
    expect(status).to be(200)
    expect(headers["content-type"]).to match(%r{^text/html\b})
    expect(content).to eq("Hello, world!")
  end
end
