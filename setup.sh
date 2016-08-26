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

function expect_nginx_exit_code() {
    local exit_code=$1
    local out=$2
    define_side_a "$exit_code"
    define_side_a_text "nginx exit code of \"$exit_code\""
    define_addl_text "nginx output:\n$out"
}

function run_nginx() {
    local out=
    out=$(nginx "$@" -c "$nginx_conf" 2>&1)
    local exit_code=$?
    out=$(<<< "$out" grep -v '/var/log/nginx/error.log')
    expect_nginx_exit_code $exit_code "$out"; to_equal 0
}

function check_nginx_conf() {
    run_nginx -t
}

function start_nginx() {
    run_nginx
}

function stop_nginx() {
    run_nginx -s stop
}
