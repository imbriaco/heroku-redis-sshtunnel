
require 'fileutils'
require 'socket'
require 'net/ssh'

class SSHTunnel
  attr_reader :socket, :user, :host, :port, :pid

  def initialize(user, host, port, key_data)
    @user, @host, @port, @key_data = user, host, port, key_data
    @socket ||= 
      begin
        path = "/tmp/ssh_tunnel_#{user}@#{host}_#{port}.sock"
        STDERR.puts "#{self.class}: Creating new UNIX socket server at #{path}." if ENV['DEBUG']
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
          STDERR.puts "#{self.class}: Establishing new SSH session to #{@user}@#{@host}." if ENV['DEBUG']
          Net::SSH.start(@host, @user, :key_data => @key_data) do |ssh|
            STDERR.puts "#{self.class}: Setting up SSH port forwarding for #{socket.path} to remote host port #{@port}." if ENV['DEBUG']
            ssh.forward.local(socket, "localhost", @port)
            ssh.loop { true }
          end
        rescue IOError => ioe
          STDERR.puts "#{self.class}: Caught IO error: #{ioe.to_s}. Attempting to reconnect."
        end
      end
    end
  end
end

