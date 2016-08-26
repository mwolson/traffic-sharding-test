worker_processes auto;
error_log {{{pwd}}}/scenario/{{{scenario}}}/log/nginx/error.log;
pid {{{pwd}}}/scenario/{{{scenario}}}/run/nginx.pid;

events {
    worker_connections 4096;
}

http {
    access_log {{{pwd}}}/scenario/{{{scenario}}}/log/nginx/access.log;

    map $uri $shard_key {
      ~^/host/(?<event_id>[^/]+)/ $event_id;
      ~^/event/(?<event_id>[^/]+)/ $event_id;
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
