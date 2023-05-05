# frozen_string_literal: true

module IOMock
  IOMOCK_CTX_KEY = :iomock_ctx

  def self.with_iomock(&block)
    old_val = Thread.current[IOMOCK_CTX_KEY]
    fibers = []
    Thread.current[IOMOCK_CTX_KEY] = fibers
    block.call
    fibers.each do |fiber|
      fiber.raise(StandardError.new("Unfinished I/O")) if fiber.alive?
    end
  ensure
    Thread.current[IOMOCK_CTX_KEY] = old_val
  end

  REACTIVE_CTX_KEY = :iomock_reactive_ctx

  def self.with_reactive_ctx(&block)
    old_val = Fiber[REACTIVE_CTX_KEY]
    Fiber[REACTIVE_CTX_KEY] = Fiber.current
    block.call
  ensure
    Fiber[REACTIVE_CTX_KEY] = old_val
  end

  def self.new(actions)
    ctx = Thread.current[IOMOCK_CTX_KEY] || raise("Not wrapped within IOMock.with_iomock")
    pipe1, pipe2 = SyncPipe.pair
    fiber = Fiber.new do
      IOMock.with_reactive_ctx do
        actions.each do |action|
          case action[0]
          when :read
            pipe2.expect_read(action[1])
          when :write
            pipe2 << action[1]
          when :close
            pipe2.close
          else
            raise "Unknown action: #{action[0]}"
          end
        end
      end
    end
    ctx << fiber
    fiber.resume
    pipe1
  end

  def self.waker
    Fiber[REACTIVE_CTX_KEY] || raise("This I/O operation would block")
  end

  class SyncPipe
    include Puro::IOAdapter

    def self.pair
      pipe1 = SyncPipe.new
      pipe2 = SyncPipe.new
      pipe1.instance_variable_set(:@opposite, pipe2)
      pipe2.instance_variable_set(:@opposite, pipe1)
      [pipe1, pipe2]
    end

    def initialize
      @write_buf = +"".b
      @read_buf = +"".b
      @read_end = false
      @read_wakers = []
    end

    def <<(obj)
      raise "Stream has already been closed" unless @write_buf

      @write_buf << obj.to_s.b
      self
    end

    def flush
      raise "Stream has already been closed" unless @write_buf

      @opposite.internal_written(@write_buf) if @write_buf.bytesize > 0
      @write_buf.clear
      self
    end

    def close_write
      @opposite.internal_written(@write_buf) if @write_buf.bytesize > 0
      @write_buf = nil
      @opposite.internal_closed
      nil
    end

    protected def internal_written(buf)
      raise "Attempted to write to already-closed pipe" if @read_end || !@read_buf

      @read_buf << buf
      internal_wake_read
    end

    protected def internal_closed
      @read_end = true
      internal_wake_read
    end

    private def internal_wake_read
      wakers = @read_wakers
      @read_wakers = []
      wakers.each(&:resume)
    end

    def expect_read(expected)
      raise "Stream already closed" if @read_buf.nil?

      loop do
        if @read_buf.start_with?(expected)
          @read_buf[0, expected.bytesize] = "".b
          return
        elsif expected.start_with?(@read_buf) && !@read_end
          # Would block
          @read_wakers << IOMock.waker
          Fiber.yield
          next
        else
          raise "Unexpected stream:\n  expected: #{expected.inspect}  received: #{@read_buf.inspect}"
        end
      end
    end

    def readpartial(maxlen, outbuf = +"".b)
      raise "Stream already closed" if @read_buf.nil?

      loop do
        if @read_buf.bytesize > 0
          len = [maxlen, @read_buf.bytesize].min
          outbuf << @read_buf[0, len]
          @read_buf[0, len] = "".b
        elsif @read_end
          raise EOFError
        else
          # Would block
          @read_wakers << IOMock.waker
          Fiber.current.resume
          next
        end
        return outbuf
      end
    end

    def ungetbyte(arg0)
      case arg0
      when nil
        nil
      when Integer
        @read_buf[0, 0] = arg0.chr
      else
        @read_buf[0, 0] = arg0
      end
    end

    def close_read
      @read_buf = nil
      nil
    end

    def close
      close_read
      close_write
    end

    def external_encoding = Encoding::ASCII_8BIT
    def internal_encoding = nil
  end
end
