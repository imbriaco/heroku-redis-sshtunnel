
require 'fileutils'
require 'socket'
require 'net/ssh'

class TCPTunnel
  attr_reader :socket, :user, :host, :port, :pid

  def initialize(user, host, port, key_data)
    @user, @host, @port, @key_data = user, host, port, key_data
    @socket ||= begin
      path = "/tmp/tcp_tunnel_#{user}@#{host}_#{port}.sock"
      FileUtils.rm_f(path)
      UNIXServer.new(path)
    end

    @pid = connect

    at_exit do
      Process.kill("TERM", @pid)
      Process.wait(@pid)
    end
  end

  private
  def connect    
    @pid = Process.fork do
      $0 = "#{self.class}: #{@user}@#{@host}:#{@port}"

      Signal.trap("TERM") do
        STDERR.puts "#{self.class}: Received TERM signal. Exiting."
        FileUtils.rm_f(@socket.path)
        exit
      end

      while true 
        begin
          Net::SSH.start(@host, @user, :key_data => @key_data) do |ssh|
            ssh.forward.local(socket, "localhost", @port)
            ssh.loop { true }
          end
        rescue IOError => ioe
          STDERR.puts "#{self.class} caught IO error: #{ioe.to_s}. Attempting to reconnect."
        end
      end
    end
  end
end

