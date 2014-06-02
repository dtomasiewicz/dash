get '/webcam' do
  WEBCAM.start
  sleep 2 # wait for it to initialize
  erb :webcam, locals: {url: WEBCAM.url}
end