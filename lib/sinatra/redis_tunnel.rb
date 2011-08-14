
require 'redis'
require 'tcp_tunnel'

module Sinatra
  module RedisTunnel
    def redis_tunnel
      return @redis_tunnel if defined?(@redis_tunnel)

      tunnel = URI.parse(ENV['TUNNEL_URL'])
      @redis_tunnel = TCPTunnel.new(tunnel.user, tunnel.host, tunnel.port, ENV['TUNNEL_SSH_KEY'])

      at_exit do
        Process.kill("TERM", @redis_tunnel.pid)
        Process.wait(@redis_tunnel.pid) 
      end
      
      return @redis_tunnel
    end
    
    def redis
      @redis ||= Redis.new(:path => redis_tunnel.socket.path, :password => ENV['REDIS_PASSWORD'])
    end

    protected

    def self.registered(app)
      app.after do
        # Explicitly close the redis client to avoid leaking SSH tunnels
        redis.quit 
      end
    end
  end

  register RedisTunnel
end

