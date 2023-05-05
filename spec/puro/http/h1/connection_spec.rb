# frozen_string_literal: true

require_relative "../../../helpers/io_mock"

RSpec.describe Puro::Http::H1::Connection do
  around do |example|
    IOMock.with_iomock do
      example.run
    end
  end

  it "does simple request-response" do
    sock = IOMock.new(
      [
        [:read, "GET / HTTP/1.1\r\n"],
        [:read, "host: example.com\r\n"],
        [:read, "\r\n"],
        [:write, "HTTP/1.1 200 OK\r\n"],
        [:write, "Content-Type: text/html\r\n"],
        [:write, "Content-Length: 13\r\n"],
        [:write, "\r\n"],
        [:flush],
        [:read_eof],
        [:close]
      ]
    )
    conn = Puro::Http::H1::Connection.new(sock)
    stream = conn.open_stream
    stream.write_headers(
      {
        ":method" => "GET",
        ":path" => "/",
        "host" => "example.com"
      }
    )
    stream.flush
    resp_headers = stream.read_headers
    expect(resp_headers).to(
      eq(
        {
          ":status" => "200",
          "content-length" => "13",
          "content-type" => "text/html"
        }
      )
    )
    conn.close
  end
end
