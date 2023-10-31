require "./libmtp.cr"
require "../dir_content"

module MTP
  alias Storages = Array(Storage)
  @@box : Pointer(Void)?

  enum EventType
    DEVICE_CONNECT
    DEVICE_DISCONNECT
    STORAGE_AVAILABLE
    COPY_BEGIN
    COPY_PROGRESS
    COPY_END
  end

  class Exception < Exception
  end

  def self.on_event(device, &callback : (LibC::Int, LibC::Int, UInt32, Void*) ->)
    boxed_data = Box.box(callback)
    @@box = boxed_data
    err = LibMTP.read_event_async(device.mtp_device, ->(i1, evt, i2, data) {
      data_as_callback = Box(typeof(callback)).unbox(data)
      data_as_callback.call(i1, evt, i2, data)
    }, boxed_data)
    raise "read_event_async" if err != 0
  end

  record Event, evt : EventType, data : (Device | Storage | String | Float64 | Int32)

  class EventManager
    @events : Channel(Event)

    def initialize
      @events = Channel(Event).new
    end

    def send(event : Event)
      @events.send(event)
      Fiber.yield
    end

    def receive : Event | Nil
      select
      when event = @events.receive
        event
      else
        Fiber.yield
      end
    end
  end

  STORAGE_ROOT = UInt32.new(LibMTP::FILES_AND_FOLDERS_ROOT)

  #
  # An entry in the current directory
  #
  class DirEntry
    getter id : UInt32
    getter parent_id : UInt32
    getter storage_id : UInt32
    getter filename : String
    getter filesize : UInt64
    getter modificationdate : Time
    getter filetype : LibC::Int

    # file pointer will be release from memory, so copy all data
    def initialize(file : LibMTP::File)
      @id = file.item_id
      @parent_id = file.parent_id
      @storage_id = file.storage_id
      @filename = String.new(file.filename)
      @filesize = file.filesize
      @modificationdate = Time.unix(file.modificationdate)
      @filetype = file.filetype
    end

    def to_s
      "#{@filename} : #{@modificationdate}"
    end

    def folder?
      @filetype == LibMTP::FileType::FOLDER.value
    end

    def file?
      @filetype != LibMTP::FileType::FOLDER.value
    end
  end

  #
  # A storage on one MTP device
  #
  class Storage
    @mtp_storage : LibMTP::DeviceStorage
    @device : Device
    @path_ids : Array(UInt32)
    @path_captions : Array(String)
    getter current_dir_entries : Array(DirEntry)
    getter id : String

    def initialize(device : Device, count : Int, storage : LibMTP::DeviceStorage)
      @id = "#{device.id}-#{count}"
      @device = device
      @mtp_storage = storage
      @path_ids = Array(UInt32).new
      @path_captions = Array(String).new
      @current_path = "/"
      @current_dir_entries = Array(DirEntry).new
      cd_home
    end

    def cd_home
      @current_dir_entries = Array(DirEntry).new
      @path_ids = Array(UInt32).new
      @path_ids = [STORAGE_ROOT]
      @path_captions = ["ROOT"]
      update_dir_entries
    end

    def cd(id : UInt32)
      idx_index = @path_ids.index(id)
      if idx_index.nil? # not in navigated dirs ? add it
        Log.trace { "#{id} #{folder?(id)}" }
        if folder?(id)
          @path_ids << id
          @path_captions << folder_name(id)
        else
          return
        end
      else # navigate to
        idx_index += 1
        @path_ids = @path_ids[0, idx_index]
        @path_captions = @path_captions[0, idx_index]
      end
    end

    def mkdir(parent_id : UInt32, folder_name : String) : UInt32
      Log.trace { "mkdir #{folder_name} in parent #{parent_id}" }
      LibMTP.create_folder(@device.mtp_device, folder_name.to_unsafe, parent_id, @mtp_storage.id)
    end

    def copy_from_host(files : Array(String), dst_folder : UInt32, total_size : UInt64)
      @device.evt_manager.send(Event.new(EventType::COPY_BEGIN, ""))
      _copy_from_host(files, dst_folder, total_size)
      @device.evt_manager.send(Event.new(EventType::COPY_END, ""))
    end

    private def _copy_from_host(files : Array(String), dst_folder_id : UInt32, total_size : UInt64) : UInt64
      Log.trace { "in _copy_from_host dst_folder_id : #{dst_folder_id}" }
      r_size = UInt64.new(0)
      files.each do |file|
        Log.trace { "copy #{file} to #{dst_folder_id}" }
        if File.info(file).directory?
          folder_name = File.basename(file)
          folder_id = mkdir(dst_folder_id, folder_name)
          if folder_id == 0
            Log.trace { "#{folder_name} already exists, search its id" }
            mtp_file = LibMTP.get_files_and_folders(@device.mtp_device, @mtp_storage.id, dst_folder_id)
            while !mtp_file.null?
              _next = mtp_file.value._next
              folder_id = mtp_file.value.item_id if String.new(mtp_file.value.filename) == folder_name
              LibMTP.destroy_file_t(mtp_file)
              mtp_file = _next
            end
            raise MTP::Exception.new("Unable to find folder #{folder_name}") if folder_id == 0
            Log.trace { "found folder id #{folder_id}" }
          end
          r_size += _copy_from_host(Dir["#{file}/*"], folder_id, total_size)
        else
          mtp_file = LibMTP.new_file_t
          raise MTP::Exception.new("Unable to allocate mtp_file") if mtp_file.null?
          mtp_file.value.filename = File.basename(file).to_unsafe
          mtp_file.value.parent_id = dst_folder_id
          mtp_file.value.storage_id = @mtp_storage.id
          mtp_file.value.filesize = File.info(file).size
          r_size += File.info(file).size
          mtp_file.value.modificationdate = File.info(file).modification_time.to_unix
          LibMTP.send_file_from_file(@device.mtp_device, file.to_unsafe, mtp_file, nil, nil)
          # mtp_file is freed by https://github.com/libmtp/libmtp/blob/master/src/libmtp.c#L6125
          # dont't raise if r != 0 because file might already exists
          # raise MTP::Exception.new("Unable to copy file #{file} - error #{r}") unless r == 0
        end
        if total_size > 0
          @device.evt_manager.send(Event.new(EventType::COPY_PROGRESS, r_size / total_size))
        end
      end
      r_size
    end

    def copy_to_host(files : Array(UInt32), dst_folder : String)
    end

    # def cp(host_pathname : String, id : UInt32)
    #   @current_dir_entries.each do |dir_entry|
    #     if dir_entry.folder?
    #       puts "mkdir host #{host_pathname}"
    #       dir_pathname = File.join(host_pathname, dir_entry.filename)
    #       cd(dir_entry.id)
    #       cp(dir_pathname, dir_entry.id)
    #       cd_pop
    #     else
    #       puts "cp #{dir_entry.filename} to host #{host_pathname}"
    #     end
    #   end
    # end

    def getdir : DirContent
      update_dir_entries
      content = DirContent.new(true, @path_ids.last)
      content.entries = @current_dir_entries.map do |de|
        DirContent::Entry.new(
          id: de.id,
          filename: de.filename,
          size: de.filesize,
          mtime: de.modificationdate,
          is_dir: de.folder?,
          writable: true,
        )
      end

      fullpath = ""
      content.paths = @path_ids.map_with_index do |id, index|
        p = DirContent::Path.new(id.to_s, @path_captions[index])
        fullpath = Path.new(fullpath, @path_captions[index]).to_s
        p
      end
      content
      # paths = [] of NamedTuple(id: String, name: String)
      # @path_ids.each_with_index do |id, index|
      #  paths << {id: id.to_s, name: @path_captions[index]}
      #  fullpath = Path.new(fullpath, @path_captions[index]).to_s
      # end
      # {entries: entries, paths: paths, meta: {writable: true, current: @path_ids.last}}
    end

    private def folder_name(id : UInt32) : String
      f = @current_dir_entries.find { |cde| cde.folder? && cde.id == id }
      if f
        f.filename
      else
        raise MTP::Exception.new("folder_name : id not found")
      end
    end

    private def folder?(id : UInt32) : Bool
      @current_dir_entries.find { |entry| entry.id == id && entry.folder? }.nil? == false
    end

    private def folder_id(filename : String) : UInt32 | Nil
      de = @current_dir_entries.find { |cde| cde.folder? && cde.filename == filename }
      de.nil? ? nil : de.id
    end

    private def update_dir_entries
      @current_dir_entries.clear
      file = LibMTP.get_files_and_folders(@device.mtp_device, @mtp_storage.id, @path_ids.last)
      while !file.null?
        # puts file.value.item_id
        @current_dir_entries << DirEntry.new(file.value)
        _next = file.value._next
        LibMTP.destroy_file_t(file)
        file = _next
      end
    end
  end

  #
  # One MTP device
  #
  class Device
    getter id : String
    getter mtp_device : LibMTP::MTPDevice*
    getter storages : Storages
    getter bus_location : UInt32
    getter devnum : UInt8
    getter name : String

    getter evt_manager : EventManager

    def initialize(evt_manager : EventManager, raw_device : LibMTP::RawDevice)
      @evt_manager = evt_manager
      @bus_location = raw_device.bus_location
      @devnum = raw_device.devnum
      # puts "In Device initialize #{@bus_location} #{@devnum}"
      @mtp_device = LibMTP.open_raw_device_uncached(pointerof(raw_device))
      raise MTP::Exception.new("mtp_device is null") if @mtp_device.null?
      @name = String.new(LibMTP.get_friendlyname(@mtp_device))
      @id = "#{@bus_location}-#{@devnum}-#{@name}"
      @storages = Storages.new
      spawn do
        cont = true
        while cont
          scan_storages
          if @storages.size > 0
            @storages.each do |storage|
              @evt_manager.send(Event.new(EventType::STORAGE_AVAILABLE, storage))
            end
            cont = false
          end
          Fiber.yield
        end
      end
    end

    def free
      if !@mtp_device.null?
        Log.trace { "Freeing device #{@id}" }
        LibMTP.release_device(@mtp_device)
        @mtp_device = Pointer(LibMTP::MTPDevice).null
      end
    end

    def finalize
      free
    end

    def scan_storages
      raise MTP::Exception.new("mtp_device is null") if @mtp_device.null?
      storage_ptr = @mtp_device.value.storage
      while !storage_ptr.null?
        @storages << Storage.new(self, @storages.size, storage_ptr.value)
        storage_ptr = storage_ptr.value._next
      end
    end
  end

  #
  # A connection to one or many MTP devices
  #
  class Connection
    getter devices : Array(Device)
    getter evt_manager : EventManager

    def initialize
      LibMTP.init
      @devices = Array(Device).new
      @evt_manager = EventManager.new

      spawn do
        # tv = LibMTP::Timeval_t.new
        # completed : LibC::Int = 0
        loop do
          # LibMTP.handle_events_timeout_completed(pointerof(tv), pointerof(completed))
          detect
          sleep(0.2)
        end
      end
    end

    def finalize
      Log.trace { "In Connection finalize" }
    end

    def device_by_id(id : String) : (Device | Nil)
      @devices.find { |d| d.id == id }
    end

    def close
      @devices.each do |device|
        device.free
      end
      @devices.clear
    end

    private def detect
      num_devices = 0
      tmp_ptr = Pointer(LibMTP::RawDevice).null
      err = LibMTP.detect_raw_device(pointerof(tmp_ptr), pointerof(num_devices))
      if err == LibMTP::Error::NONE
        detected_devices = Array(LibMTP::RawDevice).build(1) do |buffer|
          buffer.copy_from tmp_ptr, num_devices
          num_devices
        end
        # puts "#{detected_devices.size}  #{@devices.size}"
        if detected_devices.size > @devices.size
          Log.trace { "More devices" }
          detected_devices.each do |detected_device|
            if @devices.select { |d| d.bus_location == detected_device.bus_location && d.devnum == detected_device.devnum }.none?
              @devices << Device.new(@evt_manager, detected_device)
              # puts "Connect #{@devices.last}"
              @evt_manager.send(Event.new(EventType::DEVICE_CONNECT, @devices.last))
            end
          end
        end
        if detected_devices.size < @devices.size
          Log.trace { "Less devices #{detected_devices.size}" }
          @devices.each do |device|
            # detected_devices.each_with_index { |d, i| puts "#{i} #{d.bus_location} #{device.bus_location} #{d.devnum} #{device.devnum}" }
            if detected_devices.select { |d| d.bus_location == device.bus_location && d.devnum == device.devnum }.none?
              Log.trace { "Disconnect #{device}" }
              @evt_manager.send(Event.new(EventType::DEVICE_DISCONNECT, device))
              @devices.delete(device)
            end
          end
        end
        if num_devices > 0
          LibC.free(tmp_ptr)
        end
      else
        @devices.each do |device|
          @evt_manager.send(Event.new(EventType::DEVICE_DISCONNECT, device))
        end
        @devices.clear
      end
    end
  end
end
