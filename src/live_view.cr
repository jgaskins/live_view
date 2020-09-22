require "uuid"
require "uuid/json"
require "json"
require "http/web_socket"

abstract class LiveView
  VERSION = "0.1.0"
  CHANNELS = Hash(String, Channel).new
  GC_INTERVAL = 30.seconds

  # GC channels that have been disconnected
  spawn do
    loop do
      sleep GC_INTERVAL
      # Only reap disconnected channels that have been mounted or that have gone
      # too long without being mounted. Right now, we're defining that threshold
      # as having gone an entire GC interval (our channel-related GC, not
      # Crystal's) without having been mounted.
      CHANNELS.delete_if do |key, channel|
        channel.disconnected? && (
          channel.has_mounted? || channel.age > GC_INTERVAL
        )
      end
    end
  end

  @__mounted__ = false
  @__live_view_id__ : String?

  def initialize
  end

  def live_view(io, id = UUID.random.to_s)
    @__live_view_id__ = id
    CHANNELS[live_view_id.to_s] = Channel.new(self)
    io << %{<div data-live-view="#{live_view_id}"><div>}
    render_to io
    io << %{</div></div>}
  end

  def __mount__(socket)
    @__mounted__ = true
    mount socket
  end

  def __unmount__(socket)
    @__mounted__ = false
    unmount socket
  end

  # I thought about making these abstract but most of the time you only need
  # 1-2 of them, making about half of their definitions worthless.
  def mount(socket : HTTP::WebSocket)
  end
  def unmount(socket : HTTP::WebSocket)
  end
  def handle_event(event_name : String, data : String, socket : HTTP::WebSocket)
  end

  macro template(filename)
    def render_to(io)
      ECR.embed {{filename}}, io
    end
  end

  macro render(string)
    def render_to(io)
      io << {{string}}
    end
  end

  def to_s(io)
    live_view io
  end

  def update(socket : HTTP::WebSocket, buffer = IO::Memory.new)
    render_to buffer

    json = {
      render: buffer.to_s,
      id: live_view_id,
    }.to_json

    socket.send json

  # If we can't send to the socket, it's probably closed
  rescue ex : IO::Error
  end

  def update(socket : HTTP::WebSocket, buffer = IO::Memory.new)
    yield
    update socket, buffer
  end

  def live_view_id
    (@__live_view_id__ ||= UUID.random.to_s).not_nil!
  end

  def every(duration : Time::Span, &block)
    spawn do
      while mounted?
        sleep duration
        block.call if mounted?
      end
    rescue IO::Error
      # This happens when a socket closes at just the right time
    rescue ex
      ex.inspect STDERR
    end
  end

  def mounted?
    @__mounted__
  end

  def self.handle(socket)
    channel_names = Array(String).new

    socket.on_message do |msg|
      json = JSON.parse(msg)
      if channel = json["subscribe"]?
        channel_name = channel.not_nil!.as_s
        channel_names << channel_name
        CHANNELS[channel_name]
          .mount(socket)
      elsif event_name = json["event"]?
        channel_name = json["channel"].not_nil!.as_s
        data = json["data"].not_nil!.as_s
        CHANNELS[channel_name]
          .handle_event(event_name.as_s, data, socket)
      end
    rescue ex : JSON::ParseException
      # Fuck this message
    rescue ex
      STDERR.puts ex
      STDERR.puts ex.backtrace
    end

    socket.on_close do |wat|
      channel_names.each do |channel_name|
        CHANNELS[channel_name].unmount(socket)
        CHANNELS.delete channel_name
      rescue KeyError # It may have been GCed in between
      end
    end
  end

  macro javascript_tag
    <<-HTML
      <script src="https://unpkg.com/preact@8.4.2/dist/preact.min.js"></script>
      <script src="https://unpkg.com/preact-html-converter@0.4.2/dist/preact-html-converter.browser.js"></script>
      <script src="https://cdn.jsdelivr.net/gh/jgaskins/live_view/js/live-view.min.js"></script>
    HTML
  end

  # I'm not sure this class is necessary. It was kinda crucial in helping me
  # figure things out but kinda seems like an unnecessary middleman now.
  private class Channel
    getter sockets

    @sockets = Set(HTTP::WebSocket).new
    @has_mounted = false
    @created_at = Time.utc

    def initialize(@live_view : LiveView)
    end

    def mount(socket : HTTP::WebSocket)
      @has_mounted = true
      @sockets << socket
      @live_view.__mount__ socket
    end

    def unmount(socket : HTTP::WebSocket)
      @sockets.delete socket
      @live_view.__unmount__ socket
    end

    def handle_event(message, data, socket)
      @live_view.handle_event(message, data, socket)
    end

    def age
      Time.utc - @created_at
    end

    def disconnected?
      @sockets.empty?
    end

    def connected?
      !disconnected?
    end

    def has_mounted?
      @has_mounted
    end
  end
end
