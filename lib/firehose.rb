require 'faye/websocket'
require 'thread'

class Firehose
  KEEPALIVE_TIME = 15 # seconds

  def initialize(app)
    @app = app
    @clients = [] # Store connected clients
    @mutex = Mutex.new # Ensure thread safety
  end

  def call(env)
    if Faye::WebSocket.websocket?(env)
      ws = Faye::WebSocket.new(env, nil, { ping: KEEPALIVE_TIME })

      ws.on :open do |_event|
        @mutex.synchronize { @clients << ws }
        Rails.logger.info 'WebSocket connection opened'
      end

      ws.on :message do |event|
        Rails.logger.info "Received message: #{event.data}"
      end

      ws.on :close do |event|
        @mutex.synchronize { @clients.delete(ws) }
        Rails.logger.info "WebSocket connection closed: #{event.code}, #{event.reason}"
        ws = nil
      end

      ws.rack_response
    else
      @app.call(env)
    end
  end

  def broadcast(message)
    @mutex.synchronize do
      @clients.each do |client|
        client.send(message)
      end
    end
  end
end
