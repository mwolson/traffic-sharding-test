#!/bin/bash

modules=$(dirname "$BASH_SOURCE")/node_modules

. "$modules"/barrt/setup.sh
. "$modules"/barrt-curl/setup.sh

# Setup
lb_listen_port=10000
client_start_port=11000
num_clients=3

# Initial state
listen_port=
nginx_type=
scenario=

function in_range() {
    local num=$1
    local min=$2
    local max=$3
    is_numeric "$num" && is_numeric "$min" && is_numeric "$max" && \
        test $num -ge $min && test $num -le $max
}

function set_scenario() {
    scenario=${1}_${2}
    nginx_type=$2
    nginx_conf="$PWD/scenario/$scenario/etc/nginx/nginx.conf"
    if test "$nginx_type" = "lb"; then
        listen_port=$lb_listen_port
    elif in_range "$listen_port" "$client_start_port" $(($client_start_port + $num_clients - 1)); then
        $((listen_port++))
    else
        listen_port=$client_start_port
    fi
}

function count_lines() {
    wc -l | awk '{ print $1 }'
}

function mustache() {
    "$modules"/.bin/mustache "$@"
}

function clear_nginx_state() {
    for file in scenario/$scenario/etc/nginx/nginx.conf scenario/$scenario/log/nginx/*.log; do
        rm -f "$file"
    done
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
  "scenario": "$scenario",
  "listen_port": "$listen_port",
  "event_ids": ["a", "b", "c"],
  "upstreams": [
    "127.0.0.1:$((client_start_port))",
    "127.0.0.1:$((client_start_port + 1))",
    "127.0.0.1:$((client_start_port + 2))"
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
