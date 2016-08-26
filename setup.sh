#!/bin/bash

modules=$(dirname "$BASH_SOURCE")/node_modules

. "$modules"/barrt/setup.sh

# Setup
listen_port=10000
start_upstream_port=11000

# Initial state
scenario=

function set_scenario() {
    scenario=$1
    nginx_conf="$PWD/scenario/$scenario/etc/nginx/nginx.conf"
}

function count_lines() {
    wc -l | awk '{ print $1 }'
}

function mustache() {
    "$modules"/.bin/mustache "$@"
}

function render_template_for() {
    local out=$1
    local tpl=${out}.tpl
    mustache - "$tpl" > "$out"
}

function render_nginx_template() {
    render_template_for "$nginx_conf" <<EOF
{
  "pwd": "$PWD",
  "listen_port": "$listen_port",
  "upstreams": [
    "127.0.0.1:$((start_upstream_port))",
    "127.0.0.1:$((start_upstream_port + 1))",
    "127.0.0.1:$((start_upstream_port + 2))"
  ]
}
EOF
}

function check_nginx_conf() {
    local out=$(nginx -t -c "$nginx_conf" 2>&1 | grep -v '/var/log/nginx/error.log')
    expect "$out"; to_contain "nginx: the configuration file $nginx_conf syntax is ok"
}
