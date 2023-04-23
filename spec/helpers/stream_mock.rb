# frozen_string_literal: true

require "English"

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
        elsif !@write_end && expected.start_with?(part)
          break
        else
          raise "Unexpected write to the stream:\n  expected: #{expected.inspect}\n  received: #{part.inspect}"
        end
      when :write
        raise "Unexpected write after close on the other side of the stream" if @read_end

        @read_buf << @actions[@i][1]
      when :close
        @read_end = true
        @write_rej = true
      when :close_read
        @write_rej = true
      when :close_write
        @read_end = true
      end
      @i += 1
    end
    return unless @i >= @actions.size

    @read_end = true
    @write_rej = true
  end

  def <<(obj)
    raise "Write on a closed stream" if @write_buf.nil?

    @write_buf << obj.to_s.b
    internal_advance!
    self
  end

  def close_write
    @write_end = true
    internal_advance!
    nil
  end

  def read(length = nil, outbuf = +"")
    if @read_rej
      raise "Stream already closed"
    elsif length.nil? && @read_end
      outbuf[0..-1] = @read_buf
      @read_buf[0..-1] = "".b
    elsif length && (length >= @read_buf.size || @read_end)
      outbuf[0..-1] = @read_buf[0, length]
      @read_buf[0, length] = "".b
      return nil if @read_buf.empty? && length == 0
    else
      raise "Blocking read detected"
    end

    outbuf
  end

  def readpartial(maxlen, outbuf = +"")
    read(maxlen, outbuf)
  end

  def readline(rs = $RS, limit = nil, chomp: false)
    if limit.nil? && rs.is_a?(Numeric)
      limit = rs
      rs = $RS
    end
    raise "TODO: non-line mode" if rs.nil?
    raise "TODO: paragraph mode" if rs == ""

    if @read_rej
      raise "Stream already closed"
    elsif @read_buf.include?(rs) || @read_end
      nl_pos = @read_buf.index(rs)
      pos = nl_pos == -1 ? @read_buf.size : nl_pos + rs.size
      pos = [pos, limit].min if limit
      raise EOFError, "end of file reached" if pos == 0

      line = @read_buf[0, pos]
      @read_buf[0, pos] = "".b
      line = line.sub(/(\r|\r?\n)\z/, "") if chomp
      line
    else
      raise "Blocking read detected"
    end
  end

  def close_read
    @read_rej = true
    nil
  end

  def close
    close_read
    close_write
  end
end
