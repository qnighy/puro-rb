# frozen_string_literal: true

RSpec.describe "Real HTTP requests" do
  it "requests an HTTP resource successfully" do
    client = Puro::Client.new
    status, headers, content = client.request(
      :GET,
      "http://example.com"
    )
    expect(status).to be(200)
    expect(headers["content-type"]).to match(%r{^text/html\b})
    expect(content).to include("https://www.iana.org/domains/example")
  end

  it "requests an HTTPS resource successfully" do
    client = Puro::Client.new
    status, headers, content = client.request(
      :GET,
      "https://example.com"
    )
    expect(status).to be(200)
    expect(headers["content-type"]).to match(%r{^text/html\b})
    expect(content).to include("https://www.iana.org/domains/example")
  end
end
