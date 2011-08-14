Heroku Redis SSH Tunnel Example
===============================

This example application includes a Sinatra extension for connecting to Redis using a UNIX domain socket that is forwarded over an SSH tunnel to a remote server. This currently requires a patched version of the Net::SSH library, which is referenced in the Gemfile. A very simple application is included to illustrate that Redis can be accessed normally -- the tunnel management is completely abstracted into the Sinatra::RedisTunnel extension. This pattern should be easily applicable to other services that strong encryption or authentication which you want to access remotely.

First, you'll need to create an SSH keypair and setup a Redis server that can be accessed with this keypair. If you're using Ubuntu Linux, this may look something like this, assuming you're running as the root user. YMMV.

    # useradd tunnel
    # mkdir -p /home/tunnel/.ssh
    # cd /home/tunnel/.ssh
    # ssh-keygen -t rsa -f id_rsa
    Generating public/private rsa key pair.
    Enter passphrase (empty for no passphrase): 
    Enter same passphrase again: 
    Your identification has been saved in redis_example.
    Your public key has been saved in redis_example.pub.
    The key fingerprint is:
    df:b9:1b:8a:4a:b0:df:1f:72:24:29:7d:31:02:5f:0a mark@wopr
    The key's randomart image is:
    +--[ RSA 2048]----+
    |      E   .      |
    |       + o       |
    |        + o      |
    |       . o o     |
    |    . . S o      |
    |     o . = . .   |
    |    . . . + +    |
    |     o . + o o   |
    |      o.o.o o.   |
    +-----------------+
    # cp id_rsa.pub authorized_keys
    # chown -R tunnel:tunnel /home/tunnel
    # chmod 700 /home/tunnel/.ssh
    # chmod 600 /home/tunnel/.ssh/*
    # apt-get install -y redis-server
    # echo "masterauth mypassword" >> /etc/redis/redis.conf
    # /etc/init.d/redis-server restart

This example is geared to run under Heroku and you'll need to setup a few configuration variables. For TUNNEL_SSH_KEY, use the contents of the id_rsa (not id_rsa.pub) that we generated in the previous step and replace 1.2.3.4 with the hostname or IP address of the server your Redis instance is running on.

    $ heroku create --stack cedar
    $ heroku config:add TUNNEL_URL='tunnel://tunnel@1.2.3.4:6379/' TUNNEL_SSH_KEY='-----BEGIN RSA PRIVATE KEY-----...' REDIS_PASSWORD='mypassword'
    $ git push heroku master

At this point, your application should be running on Heroku and communicating with your external Redis server over an SSH tunnel. You can check to see if it's working by hitting the / URL which should return the Redis server INFO as a JSON document:

    $ curl http://redistunnel.herokuapp.com/
    {"redis_version":"2.0.4","redis_git_sha1":"00000000","redis_git_dirty":"0","arch_bits":"64","multiplexing_api":"epoll","process_id":"9513","uptime_in_seconds":"2561","uptime_in_days":"0","connected_clients":"1","connected_slaves":"0","blocked_clients":"0","used_memory":"781816","used_memory_human":"763.49K","changes_since_last_save":"0","bgsave_in_progress":"0","last_save_time":"1313356483","bgrewriteaof_in_progress":"0","total_connections_received":"605","total_commands_processed":"914","expired_keys":"0","hash_max_zipmap_entries":"512","hash_max_zipmap_value":"64","pubsub_channels":"0","pubsub_patterns":"0","vm_enabled":"0","role":"master","db0":"keys=1,expires=0"}

The server also responds to GET, POST, and DELETE using the first segment of the URI path as the key. First, we can SET a key:

    $ curl -vd 'bar' http://redistunnel.herokuapp.com/foo
    * About to connect() to redistunnel.herokuapp.com port 80 (#0)
    *   Trying 174.129.22.231... connected
    * Connected to redistunnel.herokuapp.com (174.129.22.231) port 80 (#0)
    > POST /foo HTTP/1.1
    > User-Agent: curl/7.21.4 (universal-apple-darwin11.0) libcurl/7.21.4 OpenSSL/0.9.8r zlib/1.2.5
    > Host: redistunnel.herokuapp.com
    > Accept: */*
    > Content-Length: 3
    > Content-Type: application/x-www-form-urlencoded
    > 
    < HTTP/1.1 201 Created
    < Content-Type: text/html;charset=utf-8
    < Server: thin 1.2.11 codename Bat-Shit Crazy
    < Content-Length: 0
    < Connection: keep-alive
    < 
    * Connection #0 to host redistunnel.herokuapp.com left intact
    * Closing connection #0

Then we can GET it back:

    $ curl -v http://sshtest.herokuapp.com/foo    
    * About to connect() to sshtest.herokuapp.com port 80 (#0)
    *   Trying 50.19.118.132... connected
    * Connected to sshtest.herokuapp.com (50.19.118.132) port 80 (#0)
    > GET /foo HTTP/1.1
    > User-Agent: curl/7.21.4 (universal-apple-darwin11.0) libcurl/7.21.4 OpenSSL/0.9.8r zlib/1.2.5
    > Host: sshtest.herokuapp.com
    > Accept: */*
    > 
    < HTTP/1.1 200 OK
    < Content-Type: application/json
    < Server: thin 1.2.11 codename Bat-Shit Crazy
    < Content-Length: 5
    < Connection: keep-alive
    < 
    * Connection #0 to host sshtest.herokuapp.com left intact
    * Closing connection #0
    "bar"

Next, we will DELETE it:

    $ curl -vX DELETE http://redistunnel.herokuapp.com/foo
    * About to connect() to redistunnel.herokuapp.com port 80 (#0)
    *   Trying 50.19.118.132... connected
    * Connected to redistunnel.herokuapp.com (50.19.118.132) port 80 (#0)
    > DELETE /foo HTTP/1.1
    > User-Agent: curl/7.21.4 (universal-apple-darwin11.0) libcurl/7.21.4 OpenSSL/0.9.8r zlib/1.2.5
    > Host: redistunnel.herokuapp.com
    > Accept: */*
    > 
    < HTTP/1.1 204 No Content
    < Server: thin 1.2.11 codename Bat-Shit Crazy
    < Connection: keep-alive
    < 
    * Connection #0 to host redistunnel.herokuapp.com left intact
    * Closing connection #0    

Finally, we try to GET it back again:

    $ curl -v http://redistunnel.herokuapp.com/foo
    * About to connect() to redistunnel.herokuapp.com port 80 (#0)
    *   Trying 50.19.118.132... connected
    * Connected to redistunnel.herokuapp.com (50.19.118.132) port 80 (#0)
    > GET /foo HTTP/1.1
    > User-Agent: curl/7.21.4 (universal-apple-darwin11.0) libcurl/7.21.4 OpenSSL/0.9.8r zlib/1.2.5
    > Host: redistunnel.herokuapp.com
    > Accept: */*
    > 
    < HTTP/1.1 404 Not Found
    < Content-Type: text/html;charset=utf-8
    < Server: thin 1.2.11 codename Bat-Shit Crazy
    < Content-Length: 0
    < Connection: keep-alive
    < 
    * Connection #0 to host redistunnel.herokuapp.com left intact
    * Closing connection #0

# LICENSE

Copyright (c) 2011 Mark Imbriaco

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.