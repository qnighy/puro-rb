# frozen_string_literal: true

require "puro/http/h1/line_reader"
require_relative "../../../helpers/stream_mock"

RSpec.describe Puro::Http::H1::LineReader do
  it "collects lines before empty line" do
    sock = StreamMock.new(
      [
        [:write, "Content-Type: text/html\r\n"],
        [:write, "Content-Length: 13\r\n"],
        [:write, "\r\n"],
        [:write, "Content-Type: application/json\r\n"],
        [:write, "Content-Length: 2\r\n"],
        [:write, "\r\n"],
        [:close]
      ]
    )
    lines = Puro::Http::H1::LineReader.new(sock).to_a
    expect(lines).to(
      eq(
        [
          "Content-Type: text/html",
          "Content-Length: 13"
        ]
      )
    )

    lines = Puro::Http::H1::LineReader.new(sock).to_a
    expect(lines).to(
      eq(
        [
          "Content-Type: application/json",
          "Content-Length: 2"
        ]
      )
    )
  end
end
