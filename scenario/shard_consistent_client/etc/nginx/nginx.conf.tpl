worker_processes auto;
error_log {{{pwd}}}/scenario/{{{scenario}}}/log/nginx/{{listen_port}}-error.log;
pid {{{pwd}}}/scenario/{{{scenario}}}/run/{{listen_port}}-nginx.pid;

events {
    worker_connections 4096;
}

http {
    access_log {{{pwd}}}/scenario/{{{scenario}}}/log/nginx/{{listen_port}}-access.log;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;

    map $uri $event_id {
      ~^/host/(?<match>[^/]+) $match;
      ~^/event/(?<match>[^/]+) $match;
      default $uri;
    }

    map $event_id $known {
      {{#event_ids}}
      {{{.}}} good.txt;
      {{/event_ids}}
      default bad.txt;
    }

    server {
        listen {{{listen_port}}};
        root {{{pwd}}}/common/nginx;

        location / {
            try_files /$known =404;
        }
    }
}
