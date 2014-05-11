# webcam streaming

class WebcamController

  attr_reader :url

  def initialize
    init_autostopper
  end

  def start(for_seconds = 300)
    @stop_at = for_seconds ? Time.now + for_seconds : nil
    return if @pid
    port = 5445
    path = "/#{SecureRandom.urlsafe_base64 32}"
    @pid = fork do
      exec "cvlc v4l2:// --sout '#transcode{vcodec=theo,acodec=none,vb=800,ab=128,deinterlace}:http{mux=ogg,dst=0.0.0.0:#{port}#{path}}'"
    end
    @url = "http://frawst.com:#{port}#{path}"
  end

  def stop
    Process.kill "TERM", @pid if @pid
    @pid = @url = nil
  end

  private

  def init_autostopper
    Thread.new do
      loop do
        sleep 5
        stop if @stop_at && Time.now > @stop_at
      end
    end
  end

end

WEBCAM = WebcamController.new
at_exit { WEBCAM.stop }

get '/webcam' do
  if CONFIG['allowwebcam']
    WEBCAM.start
    sleep 2 # wait for it to initialize
    erb :webcam, locals: {url: WEBCAM.url}
  else
    "Webcam not enabled :("
  end
end
