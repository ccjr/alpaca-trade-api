# frozen_string_literal: true

# Scripted WebSocket transport for streaming specs. Each connection plays the
# next script: a list of server frames (Hash/Array => JSON text, String => raw text,
# FakeTransport::Raw => exact payload/binary flag, :drop => close, Exception => raise).
# Writes are recorded per connection.
class FakeTransport
  Raw = Struct.new(:payload, :binary)

  Socket = Struct.new(:frames, :writes, :closed) do
    def read
      return if closed

      frame = frames.shift
      case frame
      when nil, :drop then nil
      when Exception, Class then raise frame
      when Raw then [frame.payload, frame.binary]
      else [frame.is_a?(String) ? frame : JSON.generate(frame), false]
      end
    end

    def write(payload, binary: false) = writes << (binary ? payload : JSON.parse(payload))

    def close = self.closed = true
  end

  attr_reader :connections, :urls, :headers

  def initialize(*scripts)
    @scripts = scripts
    @connections = []
    @urls = []
    @headers = []
  end

  def connect(url, headers: {})
    script = @scripts.shift or raise Alpaca::ConnectionError, "no more scripted connections"
    raise script if script.is_a?(Exception)

    @urls << url
    @headers << headers
    socket = Socket.new(script.dup, [], false)
    @connections << socket
    yield socket
  end

  # Writes across all connections, in order.
  def writes = connections.flat_map(&:writes)
end
