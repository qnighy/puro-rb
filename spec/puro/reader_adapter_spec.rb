# frozen_string_literal: true

require "puro/reader_adapter"

RSpec.describe Puro::ReaderAdapter do
  describe "#read" do
    describe "text mode" do
      it "forwards to #read_partial" do
        io = instance_double(IO)
        io.extend Puro::ReaderAdapter
        expect(io).to receive(:external_encoding).with(no_args).and_return(Encoding::ASCII_8BIT)
        expect(io).to receive(:internal_encoding).with(no_args).and_return(nil)
        expect(io).to receive(:readpartial).with(instance_of(Integer), instance_of(String)).and_return("Hello, ".b).once
        expect(io).to receive(:readpartial).with(instance_of(Integer), instance_of(String)).and_return("world!".b).once
        expect(io).to receive(:readpartial).with(instance_of(Integer), instance_of(String)).and_raise(EOFError).once
        expect(io.read).to eq("Hello, world!")
      end

      it "applies encoding" do
        io = instance_double(IO)
        io.extend Puro::ReaderAdapter
        expect(io).to receive(:external_encoding).with(no_args).and_return(Encoding::Windows_31J)
        expect(io).to receive(:internal_encoding).with(no_args).and_return(Encoding::UTF_8)
        expect(io).to receive(:readpartial).with(instance_of(Integer), instance_of(String)).and_return("\x82\xA0".b).once
        expect(io).to receive(:readpartial).with(instance_of(Integer), instance_of(String)).and_raise(EOFError).once
        text = io.read
        expect(text).to eq("あ")
        expect(text.encoding).to eq(Encoding::UTF_8)
      end
    end

    describe "binary mode" do
      it "forwards to #read_partial" do
        io = instance_double(IO)
        io.extend Puro::ReaderAdapter
        expect(io).to receive(:readpartial).with(10, instance_of(String)).and_return("Hello, ".b).once
        expect(io).to receive(:readpartial).with(3, instance_of(String)).and_return("wor".b).once
        expect(io.read(10)).to eq("Hello, wor")
        expect(io).to receive(:readpartial).with(10, instance_of(String)).and_return("ld!".b).once
        expect(io).to receive(:readpartial).with(instance_of(Integer), instance_of(String)).and_raise(EOFError).once
        expect(io.read(10)).to eq("ld!")
        expect(io).to receive(:readpartial).with(instance_of(Integer), instance_of(String)).and_raise(EOFError).once
        expect(io.read(10)).to eq(nil)
        expect(io).to receive(:readpartial).with(instance_of(Integer), instance_of(String)).and_raise(EOFError).once
        expect(io.read(0)).to eq("")
      end
    end
  end

  describe "#readline" do
    it "forwards to #read_partial" do
      io = instance_double(IO)
      io.extend Puro::ReaderAdapter
      expect(io).to receive(:external_encoding).with(no_args).and_return(Encoding::ASCII_8BIT)
      expect(io).to receive(:internal_encoding).with(no_args).and_return(nil)
      expect(io).to receive(:readpartial).with(instance_of(Integer)).and_return("HTTP/1".b).once
      expect(io).to receive(:readpartial).with(instance_of(Integer)).and_return(".1 200 OK\r\n".b).once
      expect(io.readline).to eq("HTTP/1.1 200 OK\r\n")
    end

    it "Puts back remainder" do
      io = instance_double(IO)
      io.extend Puro::ReaderAdapter
      expect(io).to receive(:external_encoding).with(no_args).and_return(Encoding::ASCII_8BIT)
      expect(io).to receive(:internal_encoding).with(no_args).and_return(nil)
      expect(io).to receive(:readpartial).with(instance_of(Integer)).and_return("HTTP/1.1 200 OK\r\nConten".b).once
      expect(io).to receive(:ungetbyte).with("Conten".b).once
      expect(io.readline).to eq("HTTP/1.1 200 OK\r\n")
    end

    describe "encoding" do
      it "configures ASCII_8BIT" do
        io = instance_double(IO)
        io.extend Puro::ReaderAdapter
        expect(io).to receive(:external_encoding).with(no_args).and_return(Encoding::ASCII_8BIT)
        expect(io).to receive(:internal_encoding).with(no_args).and_return(nil)
        expect(io).to receive(:readpartial).with(instance_of(Integer)).and_return("あ\n".b).once
        expect(io.readline.encoding).to eq(Encoding::ASCII_8BIT)
      end

      it "configures UTF_8" do
        io = instance_double(IO)
        io.extend Puro::ReaderAdapter
        expect(io).to receive(:external_encoding).with(no_args).and_return(Encoding::UTF_8)
        expect(io).to receive(:internal_encoding).with(no_args).and_return(nil)
        expect(io).to receive(:readpartial).with(instance_of(Integer)).and_return("あ\n".b).once
        expect(io.readline.encoding).to eq(Encoding::UTF_8)
      end

      it "applies internal encoding" do
        io = instance_double(IO)
        io.extend Puro::ReaderAdapter
        expect(io).to receive(:external_encoding).with(no_args).and_return(Encoding::Windows_31J)
        expect(io).to receive(:internal_encoding).with(no_args).and_return(Encoding::UTF_8)
        expect(io).to receive(:readpartial).with(instance_of(Integer)).and_return("\x82\xA0\n".b).once
        line = io.readline
        expect(line).to eq("あ\n")
        expect(line.encoding).to eq(Encoding::UTF_8)
      end
    end
  end
end
