# frozen_string_literal: true

require_relative "./stream_mock"

RSpec.describe StreamMock do
  it "mocks stream" do
    stream = StreamMock.new(
      [
        [:read, "ping"],
        [:write, "pong"]
      ]
    )
    stream << "ping"
    expect(stream.read(4)).to eq("pong")
  end
end
