require "minitest/autorun"
require "time/span"

require "../src/message_handler"

class Suite1Test < Minitest::Test
  @cnx = MTP::Connection.new
  @host_storage = Host::Storage.new
  @device_test_id = "0-1-"

  def setup
    Log.setup(:error)
    @handler = Message::Handler.new(@cnx, @host_storage)
  end

  def exec_timeout(seconds, &block)
    c = Channel(Bool).new
    spawn do
      block.call
      c.send(true)
    end
    select
    when r = c.receive
    when timeout(seconds.seconds)
      raise "Test timed out"
    end
  end

  def test_device_connected_and_storage_available
    mout : (Nil | Message::Out)

    mout = nil
    exec_timeout(1) do
      while mout.nil?
        mout = @handler.try &.outgoing
      end
    end
    assert_equal Message::Out::DEVICE_CONNECTED, mout.try &.msg
    assert_equal @device_test_id, mout.try &.data

    mout = nil
    exec_timeout(1) do
      while mout.nil?
        mout = @handler.try &.outgoing
      end
    end
    assert_equal Message::Out::STORAGE_AVAILABLE, mout.try &.msg
    assert_equal "#{@device_test_id}-0", mout.try &.data
  end
end
