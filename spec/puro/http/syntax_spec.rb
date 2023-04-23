# frozen_string_literal: true

# rubocop:disable Layout/LineLength

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

  describe ".parse_h1_field" do
    def parse_h1_field(...) = Puro::Http::Syntax.parse_h1_field(...)

    it "parses a simple field line" do
      expect(parse_h1_field("Content-Type: text/html".b)).to eq(["content-type", "text/html"])
    end

    it "parses a field line without whitespace" do
      expect(parse_h1_field("Content-Type:text/html".b)).to eq(["content-type", "text/html"])
    end

    it "strips arbitrary number of whitespaces in the value" do
      expect(parse_h1_field("Content-Type: \t text/html \t ".b)).to eq(["content-type", "text/html"])
    end

    # {https://datatracker.ietf.org/doc/html/rfc9110#name-field-values RFC9110§5.5} states:
    # `field-value    = *field-content`
    # This implies existence of empty field values... am I getting something wrong?
    it "parses a field line with empty value" do
      expect(parse_h1_field("Content-Type:".b)).to eq(["content-type", ""])
      # Also strip whitespaces
      expect(parse_h1_field("Content-Type: \t ".b)).to eq(["content-type", ""])
    end

    it "accepts all VCHAR other than delimiters as a field name" do
      expect(parse_h1_field("!\#$%&'*+-.^_`|~0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz: text/html".b)).to eq([
                                                                                                                                    "!\#$%&'*+-.^_`|~0123456789abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz", "text/html"
                                                                                                                                  ])
    end

    it "rejects delimiters and non-visible characters as a field name" do
      [*"\x00".."\x1F", *"\"(),/;<=>?@[\\]{}".chars, *"\x7F".."\xFF"].each do |ch|
        expect { parse_h1_field("Foo#{ch}Bar: text/html".b) }.to raise_error("Invalid header line")
      end
      # In case of ":", this is a different interpretation rather than parse error
      expect(parse_h1_field("Foo:Bar: text/html".b)).to eq(["foo", "Bar: text/html"])
    end

    it "accepts all VCHAR as a field value" do
      expect(parse_h1_field("Foo: !\"\#$%&'()*+,-./:;<=>?@[\\]^_`{/}~0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz".b)).to eq([
                                                                                                                                                 "foo", "!\"\#$%&'()*+,-./:;<=>?@[\\]^_`{/}~0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
                                                                                                                                               ])
    end

    it "accepts all upper half character as a field value (obs-text)" do
      bytes = ("\x80".b.."\xFF".b).to_a.join
      expect(parse_h1_field("Foo: #{bytes}".b)).to eq(["foo", bytes])
    end

    it "rejects non-visible 7-bit characters, other than space, as a field value" do
      ([*"\x00".b.."\x20".b, "\x7F".b] - ["\t".b, " ".b]).each do |ch|
        expect { parse_h1_field("Foo: Foo#{ch}Bar".b) }.to raise_error("Invalid header line")
      end
    end

    it "retains cases in field values" do
      expect(parse_h1_field("Foo: FooBar".b)).to eq(["foo", "FooBar"])
    end

    it "retains contiguous whitespaces in field value" do
      expect(parse_h1_field("Foo: Foo \t Bar".b)).to eq(["foo", "Foo \t Bar"])
    end

    it "errors on empty line" do
      expect { parse_h1_field("".b) }.to raise_error("Invalid header line")
    end

    it "errors on missing colon" do
      expect { parse_h1_field("Content-Type".b) }.to raise_error("Invalid header line")
    end

    it "errors on empty field name" do
      expect { parse_h1_field(": text/html".b) }.to raise_error("Invalid header line")
    end

    # This is obs-fold; should be handled somewhere other than parse_h1_field
    it "errors on space before field name" do
      expect { parse_h1_field(" Content-Type: text/html".b) }.to raise_error("Invalid header line")
    end

    it "errors on space after field name" do
      expect { parse_h1_field("Content-Type : text/html".b) }.to raise_error("Invalid header line")
    end
  end

  describe ".parse_h1_fields" do
    def parse_h1_fields(lines)
      fields = []
      Puro::Http::Syntax.parse_h1_fields(lines) do |name, value|
        fields << [name, value]
      end
      fields
    end

    it "parses field lines" do
      lines = [
        "Content-Type: text/html",
        "Content-Length: 1234"
      ]
      fields = [
        ["content-type", "text/html"],
        ["content-length", "1234"]
      ]
      expect(parse_h1_fields(lines)).to eq(fields)
    end

    it "parses obsolete line folding" do
      lines = [
        "Field1: foo",
        "\tbar ",
        " baz",
        "Content-Length: 1234"
      ]
      fields = [
        ["field1", "foo bar baz"],
        ["content-length", "1234"]
      ]
      expect(parse_h1_fields(lines)).to eq(fields)
    end

    it "rejects indentation at the top" do
      lines = [
        " Content-Type: text/html",
        "Content-Length: 1234"
      ]
      expect { parse_h1_fields(lines) }.to raise_error("Invalid header line")
    end

    it "enforces syntactic requirement of field-value to the continuation too" do
      lines = [
        "Field1: foo",
        " \v",
        "Content-Length: 1234"
      ]
      expect { parse_h1_fields(lines) }.to raise_error("Invalid header line")
    end

    it "parses empty list of lines" do
      expect(parse_h1_fields([])).to eq([])
    end
  end
end

# rubocop:enable Layout/LineLength
