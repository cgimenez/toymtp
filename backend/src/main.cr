# ruby build.rb compile patchmain
require "webview"
require "./server"

Log.setup(:trace)
chan = Channel(Bool).new
Server.new(chan).run

debug = false
nogui = false

ARGV.each do |arg|
  case arg
  when "debug"
    debug = true
  when "nogui"
    nogui = true
  end
end

Log.trace { "Waiting for the http server to be ready" }
chan.receive

if nogui
  Log.trace { "Started in nogui mode" }
  loop do
    sleep 0.2
  end
else
  port = debug ? 5173 : 3000
  Log.trace { "Client port is #{port}" }
  wv = Webview.window(1024, 768, Webview::SizeHints::NONE, "ToyMTP", "http://127.0.0.1:#{port}/index.html", true)
  wv.run
  wv.destroy
end
