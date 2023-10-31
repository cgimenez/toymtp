require "fileutils"

def recreate_dir(path)
  raise "wrong path" unless ["vendor", "../ToyMTP/lib"].include?(path)
  FileUtils.remove_dir(path) if File.directory?(path)
  Dir.mkdir(path) unless File.exists?(path)
end

def get_exe_dylib(exe_file)
  libs = `otool -L #{exe_file}`.lines.map { |l| l[/^.+\.dylib/i]&.strip }
    .reject do |l|
    l.nil? ||
    l.empty? ||
    l.start_with?("/System/Library") ||
    l.start_with?("/usr/lib") ||
    l.start_with?("@rpath")
  end
end

last_exit_code = nil
test = false
release = false
install_libs = false
stock_mtp = false # false copied from libmtp src, true copied from /opt/local/lib

more_args = []

ARGV.each do |a|
  if a[0..1] == "--"
    more_args << a
  else
    case a
    when "test"
      test = true
    when "release"
      release = true
    when "libs"
      install_libs = true
    when "stockmtp"
      stock_mtp = true
    else
      puts "Unknow command #{a}, please use : release, libs, stockmtp"
      exit
    end
  end
end

exe_name = test ? "test_suite" : "main"
src_name = test ? "test/suite1_test.cr" : "src/main.cr"
exe_directory = ""
app_directory = "."

full_exe_path = "#{app_directory}#{exe_directory}/#{exe_name}"

puts "Compiling"
if !stock_mtp
  link_flags = "-L$(pwd)/../../libmtp/src/.libs/"
else
  link_flags = ""
end

compile_flags = release ? "--release" : ""

last_exit_code = system(%[crystal build #{src_name} #{compile_flags} -o #{full_exe_path} -Dpreview_mt --link-flags="#{link_flags}" #{more_args.join(" ")}])
exit unless last_exit_code

puts "Retrieving shared libs"
if install_libs
  recreate_dir("vendor")
  get_exe_dylib(full_exe_path).each do |lib|
    blib = File.basename(lib)
    if stock_mtp == false && blib =~ /libmtp/
      FileUtils.cp "../../libmtp/src/.libs/libmtp.9.dylib", "vendor/libmtp.9.dylib"
    else
      FileUtils.cp lib, "vendor/#{blib}"
    end
    if release
      FileUtils.cp "vendor/#{blib}", "#{app_directory}/lib"
    end
  end
end

if release
  frameworks_path = "../Frameworks"
else
  frameworks_path = "vendor"
end

puts "Patching executable [frameworks_path = #{frameworks_path}]"
get_exe_dylib(full_exe_path).each do |lib|
  blib = File.basename(lib)
  dylibpath = "#{frameworks_path}/#{blib}"
  system(%[install_name_tool -change #{lib} @executable_path/#{dylibpath} #{full_exe_path}])
end

if test
  puts `#{full_exe_path}`
end
