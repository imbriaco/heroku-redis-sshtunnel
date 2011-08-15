
require 'redis'
require 'ssh_tunnel'

module Sinatra
  module RedisTunnel
    def redis_tunnel
      tunnel = URI.parse(ENV['TUNNEL_URL'])
      @redis_tunnel ||= 
        begin
          STDERR.puts "#{self.class}: Establishing new SSHTunnel connection." if ENV['DEBUG']
          SSHTunnel.new(tunnel.user, tunnel.host, tunnel.port, ENV['TUNNEL_SSH_KEY'])
        end
    end
    
    def redis
      @redis ||= 
        begin
          STDERR.puts "#{self.class}: Returning new Redis connection." if ENV['DEBUG']
          Redis.new(:path => redis_tunnel.socket.path, :password => ENV['REDIS_PASSWORD'])
        end
    end

    protected

    def self.registered(app)
      app.after do
        STDERR.puts "#{self.class}: Closing Redis client socket." if ENV['DEBUG']
        redis.quit 
      end
    end
  end

  register RedisTunnel
end

