require "json"
require "system/user"

require "./dir_content"

lib LibC
  fun getuid : UidT
  fun getgid : UidT
  fun getgroups(LibC::Int, Void*) : LibC::Int
end

module Host
  class Storage
    @user_id : System::User
    # @groups : Array(UInt32)
    @paths : Array(String)

    def initialize
      @user_id = System::User.find_by id: LibC.getuid.to_s
      @paths = Array(String).new
      cd_home
      # res = 0
      # @groups = Array(UInt32).build(64) do |buffer|
      #   res = LibC.getgroups(64, buffer)
      #   res == -1 ? 0 : res
      # end
      # Dir["/var/*"].each do |f|
      #   puts "#{f} : #{File.readable?(f)} #{File.writable?(f)} #{File.executable?(f)}"
      # end
    end

    def cd_home
      cd(@user_id.home_directory)
    end

    def cd(path : String)
      @paths = path.split("/")
    end

    def getdir : DirContent
      current_path = @paths.join("/")
      content = DirContent.new(File.writable?(current_path), current_path)
      content.entries = Dir[%[#{current_path}/*]].map do |f|
        DirContent::Entry.new(
          id: f,
          filename: File.basename(f),
          size: File.info(f).size.to_u64,
          mtime: File.info(f).modification_time,
          is_dir: File.info(f).directory?,
          writable: File.writable?(f),
        )
      end.reject { |e| File.readable?(e.id.to_s) == false }

      partial_path = "/"
      content.paths = @paths.uniq.map do |path|
        if path == "" #  root ("/") is splitted to ""
          DirContent::Path.new("/", "ROOT")
        else
          partial_path = Path.new(partial_path, path).to_s
          DirContent::Path.new(partial_path, path)
        end
      end
      content
    end

    def size(files : Array(String)) : UInt64
      r = 0.to_u64
      files.each do |f|
        if File.info(f).directory?
          r = size(Dir["#{f}/*"])
        else
          r += File.info(f).size.to_u64
        end
      end
      r
    end
  end
end
