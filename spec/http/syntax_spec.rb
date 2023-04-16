# frozen_string_literal: true

require "puro/http/syntax"

RSpec.describe Puro::Http::Syntax do
  describe ".strip_line" do
    def strip_line(...) = Puro::Http::Syntax.strip_line(...)

    it "removes CRLF" do
      expect(strip_line("HTTP/1.1 200 OK\r\n".b)).to eq("HTTP/1.1 200 OK".b)
    end

    it "raises an error on missing CRLF" do
      expect { strip_line("HTTP/1.1 200 OK".b) }.to raise_error("Incorrectly terminated line")
    end

    # Optionally implementable according to RFC9112§2.2. Not implementing here
    it "raises an error on stray LF" do
      expect { strip_line("HTTP/1.1 200 OK\n".b) }.to raise_error("Incorrectly terminated line")
    end
  end

  describe ".parse_h1_status" do
    def parse_h1_status(...) = Puro::Http::Syntax.parse_h1_status(...)

    it "parses a simple status line" do
      expect(parse_h1_status("HTTP/1.1 200 OK")).to eq(["1.1", 200])
    end

    it "errors on garbage before status" do
      expect { parse_h1_status(" HTTP/1.1 200 OK") }.to raise_error("Invalid status line")
    end

    it "errors on too short or too short status code" do
      expect { parse_h1_status("HTTP/1.1 20 OK") }.to raise_error("Invalid status line")
    end

    it "errors on too short or too long status code" do
      expect { parse_h1_status("HTTP/1.1 2000 OK") }.to raise_error("Invalid status line")
    end

    # Semantic check
    it "errors on too small status code" do
      expect { parse_h1_status("HTTP/1.1 000 OK") }.to raise_error("Invalid status line")
    end

    it "errors on too large status code" do
      expect { parse_h1_status("HTTP/1.1 600 OK") }.to raise_error("Invalid status line")
    end
  end
end
