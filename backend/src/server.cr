require "kemal"
require "./message_handler"

class Server
  def initialize(chan : Channel(Bool))
    @startup_chan = chan
    @cnx = MTP::Connection.new
    @host_storage = Host::Storage.new
    @handler = Message::Handler.new(@cnx, @host_storage)
  end

  def run
    public_path = File.expand_path(Path.new(Dir.current, "../frontend/dist"))
    Log.info { "Kemal public path is #{public_path}" }
    public_folder public_path
    logging false

    spawn do
      ws "/" do |socket|
        begin
          Log.trace { "Socket new connection" }
          spawn do
            loop do
              break if socket.closed?
              resp = @handler.outgoing
              unless resp.nil?
                socket.send({msg: resp.msg, data: resp.data}.to_json)
              end
              sleep 0.2
            end
          end

          socket.on_message do |message|
            @handler.incoming(message)
          end

          socket.on_close do
            Log.trace { "Socket closing" }
            # reset
          end
        rescue ex : MTP::Exception
          Log.error { "Exception #{ex.message}" }
          socket.send({msg: Message::Out::FATAL, data: ex.message}.to_json)
        end
      end

      Kemal.run do
        @startup_chan.send(true)
        Log.info { "HTTP Server started" }
      end
    end
  end
end
