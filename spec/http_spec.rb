# frozen_string_literal: true

require "puro"
require "socket"
require_relative "./helpers/io_mock"

RSpec.describe "http" do # rubocop:disable RSpec/DescribeClass
  describe "http" do
    it "requests an HTTP resource successfully (real)" do
      status, headers, content = Puro::Http.request(
        :GET,
        "http://example.com",
        middlewares: [Puro::BaseMiddleware]
      )
      expect(status).to be(200)
      expect(headers["content-type"]).to match(%r{^text/html\b})
      expect(content).to include("https://www.iana.org/domains/example")
    end

    it "requests an HTTPS resource successfully (real)" do
      status, headers, content = Puro::Http.request(
        :GET,
        "https://example.com",
        middlewares: [Puro::BaseMiddleware]
      )
      expect(status).to be(200)
      expect(headers["content-type"]).to match(%r{^text/html\b})
      expect(content).to include("https://www.iana.org/domains/example")
    end

    it "requests an HTTP resource successfully (mocked)" do
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

      middleware = Object.new
      middleware.extend(Puro::Middleware)
      allow(middleware).to receive(:connect_tcp).and_return(sock)

      status, headers, content = Puro::Http.request(
        :GET,
        "http://example.com",
        middlewares: [middleware, Puro::BaseMiddleware]
      )
      expect(status).to be(200)
      expect(headers["content-type"]).to match(%r{^text/html\b})
      expect(content).to eq("Hello, world!")

      expect(middleware).to have_received(:connect_tcp).with(anything, anything, "example.com", 80).once
    end

    it "requests an HTTPS resource successfully (mocked)" do
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

      middleware = Object.new
      middleware.extend(Puro::Middleware)
      allow(middleware).to receive(:connect_tls).and_return(sock)

      status, headers, content = Puro::Http.request(
        :GET,
        "https://example.com",
        middlewares: [middleware, Puro::BaseMiddleware]
      )
      expect(status).to be(200)
      expect(headers["content-type"]).to match(%r{^text/html\b})
      expect(content).to eq("Hello, world!")

      expect(middleware).to have_received(:connect_tls).with(anything, anything, "example.com", 443).once
    end
  end
end
