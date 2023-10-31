require "json"
require "log"

require "./mtp/mtp"
require "./host_storage"

module Message
  alias ParamsT = (Nil | Float64 | String | Array(String) | DirContent)

  struct Out
    DEVICE_CONNECTED    = "DEVICE_CONNECTED"
    STORAGE_AVAILABLE   = "STORAGE_AVAILABLE"
    DEVICE_DISCONNECTED = "DEVICE_DISCONNECTED"
    HOSTDIR             = "HOSTDIR"
    DEVICES             = "DEVICES"
    DEVICEDIR           = "DEVICEDIR"
    COPY_BEGIN          = "COPY_BEGIN"
    COPY_PROGRESS       = "COPY_PROGRESS"
    COPY_END            = "COPY_END"
    FATAL               = "FATAL"

    getter msg : String
    getter data : ParamsT

    def initialize(msg : String, data : ParamsT)
      @msg = msg
      @data = data
    end

    def to_json : Json::Any
      Log.trace { "SEND #{@msg} #{@data}" }
      {msg: @msg, data: @data}.to_json
    end
  end

  struct In
    HOST_CD        = "HOST_CD"
    HOST_GETDIR    = "HOST_GETDIR"
    GET_DEVICES    = "GET_DEVICES"
    SELECT_DEVICE  = "SELECT_DEVICE"
    SELECT_STORAGE = "SELECT_STORAGE"
    DEVICE_CD      = "DEVICE_CD"
    DEVICE_GETDIR  = "DEVICE_GETDIR"
    COPY_FROM_HOST = "COPY_FROM_HOST"
    COPY_TO_HOST   = "COPY_TO_HOST"
  end

  class Handler
    @selected_device : (MTP::Device | Nil)
    @selected_storage : (MTP::Storage | Nil)
    @cnx : MTP::Connection
    @host_storage : Host::Storage

    def initialize(cnx, host_storage)
      @cnx = cnx
      @host_storage = host_storage
    end

    def incoming(message : String) : (Nil | Out)
      data = JSON.parse(message)
      msg = data["msg"].as_s
      params = data["params"]
      Log.trace { "RECV message #{msg} #{params}" }

      selected_device = @selected_device
      selected_storage = @selected_storage

      case msg
      when In::HOST_CD
        @host_storage.cd(params["id"].as_s)
        nil
      when In::HOST_GETDIR
        Out.new(Out::HOSTDIR, @host_storage.getdir)
      when In::GET_DEVICES
        Out.new(Out::DEVICES, @cnx.devices.map(&.id))
      when In::SELECT_DEVICE
        @selected_device = @cnx.device_by_id(params.as_s)
        nil
      when In::SELECT_STORAGE
        unless selected_device.nil?
          @selected_storage = selected_device.storages.first
        end
        nil
      when In::DEVICE_CD
        unless selected_storage.nil?
          selected_storage.cd(UInt32.new(params["id"].as_i64))
        end
        nil
      when In::DEVICE_GETDIR
        unless selected_storage.nil?
          Out.new(Out::DEVICEDIR, selected_storage.getdir)
        end
      when In::COPY_FROM_HOST
        unless selected_storage.nil?
          params = params["params"].as_h
          files = params["files"].as_a.map &.as_s
          destination = UInt32.new(params["destination"].as_i64)
          selected_storage.copy_from_host(files, destination, @host_storage.size(files))
        end
        nil
      end
    end

    def outgoing : (Nil | Out)
      mtp_event = @cnx.evt_manager.receive
      unless mtp_event.nil?
        if mtp_event.data.is_a?(MTP::Device)
          device = mtp_event.data.as(MTP::Device)
          case mtp_event.evt
          when MTP::EventType::DEVICE_CONNECT
            Out.new(Out::DEVICE_CONNECTED, device.id)
          when MTP::EventType::DEVICE_DISCONNECT
            Out.new(Out::DEVICE_DISCONNECTED, device.id)
          end
        elsif mtp_event.data.is_a?(MTP::Storage)
          storage = mtp_event.data.as(MTP::Storage)
          case mtp_event.evt
          when MTP::EventType::STORAGE_AVAILABLE
            @selected_storage = storage
            Out.new(Out::STORAGE_AVAILABLE, storage.id)
          end
        else
          case mtp_event.evt
          when MTP::EventType::COPY_BEGIN
            Out.new(Out::COPY_BEGIN, nil)
          when MTP::EventType::COPY_PROGRESS
            Out.new(Out::COPY_PROGRESS, mtp_event.data.as(Float64))
          when MTP::EventType::COPY_END
            Out.new(Out::COPY_END, nil)
          end
        end
      end
    end
  end
end
