# frozen_string_literal: true

require "puro/reader_adapter"
require_relative "../helpers/double_ext"

RSpec.describe Puro::ReaderAdapter do
  describe "#read" do
    describe "text mode" do
      it "forwards to #read_partial" do
        io = instance_double(IO)
        io.extend Puro::ReaderAdapter
        allow(io).to receive(:external_encoding).with(no_args).and_return(Encoding::ASCII_8BIT)
        allow(io).to receive(:internal_encoding).with(no_args).and_return(nil)
        allow(io).to receive(:readpartial).with(instance_of(Integer), instance_of(String)).and_return_or_raise(
          "Hello, ".b, "world!".b, EOFError
        )
        expect(io.read).to eq("Hello, world!")
        expect(io).to have_received(:readpartial).thrice
      end

      it "applies encoding" do
        io = instance_double(IO)
        io.extend Puro::ReaderAdapter
        allow(io).to receive(:external_encoding).with(no_args).and_return(Encoding::Windows_31J)
        allow(io).to receive(:internal_encoding).with(no_args).and_return(Encoding::UTF_8)
        allow(io).to receive(:readpartial).with(instance_of(Integer),
                                                instance_of(String)).and_return_or_raise("\x82\xA0".b, EOFError)
        text = io.read
        expect(text).to eq("あ")
        expect(text.encoding).to eq(Encoding::UTF_8)
      end
    end

    describe "binary mode" do
      it "forwards to #read_partial" do
        io = instance_double(IO)
        io.extend Puro::ReaderAdapter
        allow(io).to receive(:readpartial).with(10, instance_of(String)).and_return("Hello, ".b)
        allow(io).to receive(:readpartial).with(3, instance_of(String)).and_return("wor".b)
        expect(io.read(10)).to eq("Hello, wor")
        RSpec::Mocks.space.proxy_for(io).reset

        allow(io).to receive(:readpartial).with(10, instance_of(String)).and_return("ld!".b)
        allow(io).to receive(:readpartial).with(7, instance_of(String)).and_raise(EOFError)
        expect(io.read(10)).to eq("ld!")
        RSpec::Mocks.space.proxy_for(io).reset

        allow(io).to receive(:readpartial).with(instance_of(Integer), instance_of(String)).and_raise(EOFError)
        expect(io.read(10)).to eq(nil)
        RSpec::Mocks.space.proxy_for(io).reset

        allow(io).to receive(:readpartial).with(instance_of(Integer), instance_of(String)).and_raise(EOFError)
        expect(io.read(0)).to eq("")
      end
    end
  end

  describe "#readline" do
    it "forwards to #read_partial" do
      io = instance_double(IO)
      io.extend Puro::ReaderAdapter
      allow(io).to receive(:external_encoding).with(no_args).and_return(Encoding::ASCII_8BIT)
      allow(io).to receive(:internal_encoding).with(no_args).and_return(nil)
      allow(io).to receive(:readpartial).with(instance_of(Integer)).and_return("HTTP/1".b, ".1 200 OK\r\n".b)
      expect(io.readline).to eq("HTTP/1.1 200 OK\r\n")
      expect(io).to have_received(:readpartial).twice
    end

    it "Puts back remainder" do
      io = instance_double(IO)
      io.extend Puro::ReaderAdapter
      allow(io).to receive(:external_encoding).with(no_args).and_return(Encoding::ASCII_8BIT)
      allow(io).to receive(:internal_encoding).with(no_args).and_return(nil)
      allow(io).to receive(:readpartial).with(instance_of(Integer)).and_return("HTTP/1.1 200 OK\r\nConten".b)
      allow(io).to receive(:ungetbyte)
      expect(io.readline).to eq("HTTP/1.1 200 OK\r\n")
      expect(io).to have_received(:readpartial).once
      expect(io).to have_received(:ungetbyte).with("Conten".b).once
    end

    describe "encoding" do
      it "configures ASCII_8BIT" do
        io = instance_double(IO)
        io.extend Puro::ReaderAdapter
        allow(io).to receive(:external_encoding).with(no_args).and_return(Encoding::ASCII_8BIT)
        allow(io).to receive(:internal_encoding).with(no_args).and_return(nil)
        allow(io).to receive(:readpartial).with(instance_of(Integer)).and_return("あ\n".b)
        expect(io.readline.encoding).to eq(Encoding::ASCII_8BIT)
      end

      it "configures UTF_8" do
        io = instance_double(IO)
        io.extend Puro::ReaderAdapter
        allow(io).to receive(:external_encoding).with(no_args).and_return(Encoding::UTF_8)
        allow(io).to receive(:internal_encoding).with(no_args).and_return(nil)
        allow(io).to receive(:readpartial).with(instance_of(Integer)).and_return("あ\n".b)
        expect(io.readline.encoding).to eq(Encoding::UTF_8)
      end

      it "applies internal encoding" do
        io = instance_double(IO)
        io.extend Puro::ReaderAdapter
        allow(io).to receive(:external_encoding).with(no_args).and_return(Encoding::Windows_31J)
        allow(io).to receive(:internal_encoding).with(no_args).and_return(Encoding::UTF_8)
        allow(io).to receive(:readpartial).with(instance_of(Integer)).and_return("\x82\xA0\n".b)
        line = io.readline
        expect(line).to eq("あ\n")
        expect(line.encoding).to eq(Encoding::UTF_8)
      end
    end
  end
end
