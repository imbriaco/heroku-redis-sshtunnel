
$:.unshift('lib/')

require 'sinatra'
require 'sinatra/redis_tunnel'
require 'json'

get '/' do
  redis.info.to_json
end

get '/:key' do
  content = redis.get(params[:key])
  if content.nil?
    status 404
  else
    content_type 'application/json'
    content.to_json
  end
end

post '/:key' do
  retval = redis.set(params[:key], request.body.read)

  if retval != "OK"
    status 500
    body retval
  else
    status 201
  end
end

delete '/:key' do
  redis.del(params[:key])
  status 204
end

