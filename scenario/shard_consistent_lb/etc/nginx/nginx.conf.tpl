worker_processes auto;
error_log {{{pwd}}}/scenario/{{{scenario}}}/log/nginx/error.log;
pid {{{pwd}}}/scenario/{{{scenario}}}/run/nginx.pid;

events {
    worker_connections 4096;
}

http {
    log_format upstreamlog '$remote_addr - $remote_user [$time_local] "$request" $status $body_bytes_sent "$http_referer" "$http_user_agent" to:<$upstream_addr> in:<$request_time>';
    access_log {{{pwd}}}/scenario/{{{scenario}}}/log/nginx/access.log upstreamlog;

    sendfile on;
    aio threads;
    tcp_nopush on;
    tcp_nodelay on;

    map $uri $shard_key {
      ~^/host/(?<event_id>[^/]+) $event_id;
      ~^/event/(?<event_id>[^/]+) $event_id;
      default $uri;
    }

    upstream nodejs {
        hash $shard_key consistent;
        {{#upstreams}}
        server {{{.}}};
        {{/upstreams}}
    }

    server {
        listen {{{listen_port}}};

        location / {
            proxy_pass http://nodejs;
        }
    }
}
