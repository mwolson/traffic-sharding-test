#!/bin/bash

modules=$(dirname "$BASH_SOURCE")/node_modules

. "$modules"/barrt/setup.sh
. "$modules"/barrt-curl/setup.sh
. "$modules"/barrt-nginx/setup.sh

# Setup
lb_listen_port=10000
client_start_port=11000
num_clients=3

# Initial state
listen_port=
nginx_conf_tpl=
nginx_type=
prev_listen_port=
scenario=
scenario_base=
stashed_listen_port=
stashed_nginx_type=
stashed_scenario_base=
wrk_output=

function set_nginx_scenario_base() {
    scenario_base=$1
}

function set_nginx_scenario() {
    scenario_base=$1
    nginx_type=$2
    scenario=${scenario_base}_${nginx_type}
    prev_listen_port=$listen_port
    if test "$nginx_type" = "lb"; then
        set_nginx_access_log scenario/${scenario}/log/nginx/access.log
        set_nginx_error_log scenario/${scenario}/log/nginx/error.log
        set_nginx_conf "$PWD/scenario/$scenario/etc/nginx/nginx.conf"
        nginx_conf_tpl="$PWD/scenario/$scenario/etc/nginx/nginx.conf.tpl"
        listen_port=$lb_listen_port
    else
        if is_between "$listen_port" "$client_start_port" $(($client_start_port + $num_clients - 2)); then
            ((listen_port++))
        else
            listen_port=$client_start_port
        fi
        set_nginx_access_log scenario/${scenario}/log/nginx/${listen_port}-access.log
        set_nginx_error_log scenario/${scenario}/log/nginx/${listen_port}-error.log
        set_nginx_conf "$PWD/scenario/$scenario/etc/nginx/${listen_port}-nginx.conf"
        nginx_conf_tpl="$PWD/scenario/$scenario/etc/nginx/nginx.conf.tpl"
    fi
}

function stash_nginx_scenario() {
    stashed_scenario_base=$scenario_base
    stashed_nginx_type=$nginx_type
    stashed_listen_port=$prev_listen_port
}

function pop_nginx_scenario() {
    listen_port=$stashed_listen_port
    set_nginx_scenario "$stashed_scenario_base" "$stashed_nginx_type"
}

function mustache() {
    "$modules"/.bin/mustache "$@"
}

function clear_nginx_state() {
    rm -f "$(get_nginx_access_log)" "$(get_nginx_error_log)"

    if test "$nginx_type" = "lb"; then
        rm -f scenario/$scenario/etc/nginx/*.conf
    else
        rm -f scenario/$scenario/etc/nginx/${listen_port}-*.conf
    fi
}

function render_template() {
    local tpl=$1
    local out=$2
    mustache - "$tpl" > "$out"
}

function list_nginx_upstreams() {
    local idx=0
    while test $idx -lt $num_clients; do
        echo "127.0.0.1:$((client_start_port + $idx))"
        ((idx++))
    done
}

function print_nginx_template() {
    cat <<EOF
{
  "pwd": "$PWD",
  "scenario": "$scenario",
  "listen_port": "$listen_port",
  "event_ids": ["a", "b", "c"],
  "upstreams": $(print_json_array $(list_nginx_upstreams))
}
EOF
}

function render_nginx_template() {
    print_nginx_template | render_template "$nginx_conf_tpl" "$(get_nginx_conf)"
}

function start_all_nginx_instances() {
    set_nginx_scenario "$scenario_base" lb
    : $(stop_nginx)
    clear_nginx_state
    render_nginx_template
    start_nginx

    for upstream in $(list_nginx_upstreams); do
        set_nginx_scenario "$scenario_base" client
        : $(stop_nginx)
        clear_nginx_state
        render_nginx_template
        start_nginx
    done
}

function stop_all_nginx_instances() {
    local permissive=$1

    set_nginx_scenario "$scenario_base" lb
    stop_nginx

    for upstream in $(list_nginx_upstreams); do
        set_nginx_scenario "$scenario_base" client
        stop_nginx
    done
}

function reset_all_nginx_logs() {
    stash_nginx_scenario

    set_nginx_scenario "$scenario_base" lb
    truncate_nginx_logs

    for upstream in $(list_nginx_upstreams); do
        set_nginx_scenario "$scenario_base" client
        truncate_nginx_logs
    done

    pop_nginx_scenario
}

function expect_nginx_routed_upstreams() {
    local file=$(get_nginx_access_log)
    local upstreams=$(< "$file" sed 's/.*to:<([^>]+)>.*/\1/')
    define_side_a "$upstreams"
    define_side_a_text "routing to upstream servers in nginx access log $file"
    define_addl_text "Entries:\n$upstreams"
}

function record_wrk() {
    _reset_assertion_state
    wrk_output=$(wrk "$@")
    local status=$?
    if test $status -ne 0; then
        fail "wrk command failed with status code $status"
    fi
}

function expect_wrk_socket_errors() {
    local dropped=$(<<< "$wrk_output" grep -i 'socket errors' | sed 's/^ +//')
    define_side_a "$dropped"
    define_side_a_text "number of socket errors counted by wrk"
    define_addl_text "${dropped}\n\nwrk output:\n$wrk_output"
}
