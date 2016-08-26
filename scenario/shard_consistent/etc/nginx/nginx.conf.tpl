worker_processes auto;
error_log {{{pwd}}}/scenario/shard_consistent/log/nginx/error.log;
pid {{{pwd}}}/scenario/shard_consistent/run/nginx.pid;

events {
    worker_connections 4096;
}

http {
    access_log {{{pwd}}}/scenario/shard_consistent/log/nginx/access.log;

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
