# frozen_string_literal: true

require "puro/reader_adapter"

RSpec.describe Puro::ReaderAdapter do
  describe "#readline" do
    it "forwards to #read_partial" do
      io = instance_double(IO)
      io.extend Puro::ReaderAdapter
      expect(io).to receive(:readpartial).with(instance_of(Integer)).and_return("HTTP/1".b).once
      expect(io).to receive(:readpartial).with(instance_of(Integer)).and_return(".1 200 OK\r\n".b).once
      expect(io.readline).to eq("HTTP/1.1 200 OK\r\n")
    end

    it "Puts back remainder" do
      io = instance_double(IO)
      io.extend Puro::ReaderAdapter
      expect(io).to receive(:readpartial).with(instance_of(Integer)).and_return("HTTP/1.1 200 OK\r\nConten".b).once
      expect(io).to receive(:ungetbyte).with("Conten".b).once
      expect(io.readline).to eq("HTTP/1.1 200 OK\r\n")
    end
  end
end
