# frozen_string_literal: true

require_relative "./io_mock"

RSpec.describe IOMock do
  it "mocks stream" do
    stream = IOMock.new(
      [
        [:read, "ping"],
        [:write, "pong"]
      ]
    )
    stream << "ping"
    stream.flush
    expect(stream.read(4)).to eq("pong")
  end
end
