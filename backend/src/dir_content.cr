class DirContent
  include JSON::Serializable

  alias EntryID = (String | UInt32)
  record Entry, id : EntryID, filename : String, size : UInt64, mtime : Time, is_dir : Bool, writable : Bool { include JSON::Serializable }
  record Path, id : EntryID, name : String { include JSON::Serializable }
  record Meta, writable : Bool, current : EntryID { include JSON::Serializable }

  setter entries : Array(Entry)
  setter paths : Array(Path)
  setter meta : Meta

  def initialize(meta_writable, meta_current_path)
    @entries = Array(Entry).new
    @paths = Array(Path).new
    @meta = Meta.new(meta_writable, meta_current_path)
  end

  # def values
  #  {entries: @entries, paths: @paths, meta: @meta}
  # end
end
