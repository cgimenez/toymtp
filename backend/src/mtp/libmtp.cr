@[Link("mtp")]

lib LibMTP
  {% if flag?(:bits64) %}
    alias Time_t = UInt64
    alias Enum_t = UInt32
  {% else %}
    alias Time_t = UInt32
    alias Enum_t = UInt32
  {% end %}

  alias EventT = Enum_t

  FILES_AND_FOLDERS_ROOT = 0xffffffff

  alias EventCallbackFn = (LibC::Int, LibC::Int, UInt32, Void*) -> Void
  type ErrorCode = UInt32

  enum Error
    NONE
    GENERAL
    PTP_LAYER
    USB_LAYER
    MEMORY_ALLOCATION
    NO_DEVICE_ATTACHED
    STORAGE_FULL
    CONNECTING
    CANCELLED
  end

  enum Event
    NONE
    STORE_ADDED
    STORE_REMOVED
    OBJECT_ADDED
    OBJECT_REMOVED
    DEVICE_PROPERTY_CHANGED
  end

  enum FileType
    FOLDER
    WAV
    MP3
    WMA
    OGG
    AUDIBLE
    MP4
    UNDEF_AUDIO
    WMV
    AVI
    MPEG
    ASF
    QT
    UNDEF_VIDEO
    JPEG
    JFIF
    TIFF
    BMP
    GIF
    PICT
    PNG
    VCALENDAR1
    VCALENDAR2
    VCARD2
    VCARD3
    WINDOWSIMAGEFORMAT
    WINEXEC
    TEXT
    HTML
    FIRMWARE
    AAC
    MEDIACARD
    FLAC
    MP2
    M4A
    DOC
    XML
    XLS
    PPT
    MHT
    JP2
    JPX
    ALBUM
    PLAYLIST
    UNKNOWN
  end

  # struct Timeval_t
  #  tv_sec : Time_t
  #  tv_usec : LibC::Int
  # end

  struct ErrorT
    errornumber : UInt32
    error_text : LibC::Char*
    _next : Error*
  end

  struct File
    item_id : UInt32
    parent_id : UInt32
    storage_id : UInt32
    filename : LibC::Char*
    filesize : UInt64
    modificationdate : LibC::TimeT # was Time_t
    filetype : LibC::Int           # Warn - enum
    _next : File*
  end

  struct Folder
    folder_id : UInt32
    parent_id : UInt32
    storage_id : UInt32
    name : LibC::Char*
    sibling : Folder*
    child : Folder*
  end

  struct DeviceStorage
    id : UInt32
    storage_type : UInt16
    filesystem_type : UInt16
    access_capability : UInt16
    max_capacity : UInt64
    free_space_in_bytes : UInt64
    free_space_in_objects : UInt64
    storage_description : LibC::Char*
    volume_identifier : LibC::Char*
    _next : DeviceStorage*
    _prev : DeviceStorage*
  end

  struct DeviceExtension
    name : LibC::Char*
    major : LibC::Int
    minor : LibC::Int
    _next : DeviceExtension*
  end

  struct MTPDevice
    object_bitsize : UInt8
    params : Void*
    usbinfo : Void*
    storage : DeviceStorage*
    errorstack : Error*
    maximum_battery_level : UInt8
    default_music_folder : UInt32
    default_playlist_folder : UInt32
    default_picture_folder : UInt32
    default_video_folder : UInt32
    default_organizer_folder : UInt32
    default_zencast_folder : UInt32
    default_album_folder : UInt32
    default_text_folder : UInt32
    cd : Void*
    extensions : DeviceExtension*
    cached : LibC::Int
    _next : MTPDevice*
  end

  struct DeviceEntry
    vendor : LibC::Char*
    vendor_id : UInt16
    product : LibC::Char*
    product_id : UInt16
    device_flags : UInt32
  end

  struct RawDevice
    device_entry : DeviceEntry
    bus_location : UInt32
    devnum : UInt8
  end

  type RawDevicePtr = RawDevice*
  type MTPDevicePtr = MTPDevice*

  fun init = LIBMTP_Init

  fun detect_raw_device = LIBMTP_Detect_Raw_Devices(RawDevice**, LibC::Int*) : Error
  fun get_first_device = LIBMTP_Get_First_Device : MTPDevice*
  fun get_friendlyname = LIBMTP_Get_Friendlyname(MTPDevice*) : LibC::Char*

  fun open_raw_device_uncached = LIBMTP_Open_Raw_Device_Uncached(RawDevice*) : MTPDevice*
  fun release_device = LIBMTP_Release_Device(MTPDevice*)

  fun get_files_and_folders = LIBMTP_Get_Files_And_Folders(MTPDevice*, UInt32, LibC::Int) : File*
  fun create_folder = LIBMTP_Create_Folder(MTPDevice*, LibC::Char*, UInt32, UInt32) : UInt32

  fun send_file_from_file = LIBMTP_Send_File_From_File(device : MTPDevice*, path : LibC::Char*, filedata : File*, callback : Void*, data : Void*) : LibC::Int

  fun new_file_t = LIBMTP_new_file_t : File*
  fun destroy_file_t = LIBMTP_destroy_file_t(file : File*)

  fun read_event = LIBMTP_Read_Event(MTPDevice*, EventT*, UInt32*) : LibC::Int
  fun read_event_async = LIBMTP_Read_Event_Async(MTPDevice*, (LibC::Int, LibC::Int, UInt32, Void*) ->, Void*) : LibC::Int
  # fun read_event_async = LIBMTP_Read_Event_Async(MTPDevice*, EventCallbackFn, Void*) : LibC::Int
  fun handle_events_timeout_completed = LIBMTP_Handle_Events_Timeout_Completed(LibC::Timeval*, LibC::Int*) : LibC::Int
end
