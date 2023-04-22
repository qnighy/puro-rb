class StreamMock
  def initialize(actions)
    @actions = actions
    @i = 0
    @read_buf = "".b
    @read_end = false
    @read_rej = false
    @write_buf = "".b
    @write_end = false
    @write_rej = false
    internal_advance!
  end

  private def internal_advance!
    while @actions[@i]
      case @actions[@i][0]
      when :read
        raise "Unexpected read after close on the other side of the stream" if @write_rej

        expected = @actions[@i][1]
        part = @write_buf[0, expected.size]
        if part == expected
          @write_buf[0, expected.size] = "".b
          @i += 1
        elsif !@write_end && expected.start_with?(part)
          break
        else
          raise "Unexpected write to the stream:\n  expected: #{expected.inspect}\n  received: #{part.inspect}"
        end
      when :write
        raise "Unexpected write after close on the other side of the stream" if @read_end

        @read_buf << @actions[@i][1]
        @i += 1
      when :close
        @read_end = true
        @write_rej = true
      when :close_read
        @write_rej = true
      when :close_write
        @read_end = true
      end
    end
    if @i >= @actions.size
      @read_end = true
      @write_rej = true
    end
  end

  def <<(obj)
    raise "Write on a closed stream" if @write_buf.nil?

    @write_buf << obj.to_s.b
    internal_advance!
    self
  end

  def read(length = nil, outbuf = "")
    raise NotImplementedError, "TODO: text-reading" if length.nil?

    if @read_rej
      raise "Stream already closed"
    elsif length >= @read_buf.size || @read_end
      outbuf[0..-1] = @read_buf[0, length]
      @read_buf[0, length] = "".b
    else
      raise "Blocking read detected"
    end

    outbuf
  end
end
