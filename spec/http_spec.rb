# frozen_string_literal: true

require "socket"

RSpec.describe "http" do
  def get
    sock = Socket.tcp("example.com", 80)
    sock << "GET / HTTP/1.1\r\nHost: example.com\r\nUser-Agent: test\r\nAccept: text/html\r\n\r\n"
    sock.close_write

    line = Puro::Http::Syntax.strip_line(sock.readline)
    _version, status = Puro::Http::Syntax.parse_h1_status(line)

    headers = {};
    loop do
      line = Puro::Http::Syntax.strip_line(sock.readline)
      break if line.empty?

      name, value = Puro::Http::Syntax.parse_h1_field(line)
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
