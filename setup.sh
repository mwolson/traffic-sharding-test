#!/bin/bash

modules=$(dirname "$BASH_SOURCE")/node_modules

. "$modules"/barrt/setup.sh
. "$modules"/barrt-curl/setup.sh
. "$modules"/barrt-nginx/setup.sh
. "$modules"/barrt-wrk/setup.sh

function on_os_x() {
    test "$(uname -s)" = "Darwin"
}

# Setup
lb_listen_port=10000
client_start_port=11000
num_clients=3
wrk_connections=$(if on_os_x; then get_wrk_os_x_safe_connection_limit; else echo 500; fi)

# Initial state
listen_port=
nginx_conf_tpl=
nginx_routing_summary=
nginx_type=
prev_listen_port=
scenario=
scenario_base=
stashed_listen_port=
stashed_nginx_type=
stashed_scenario_base=

function set_nginx_scenario_base() {
    scenario_base=$1
}

function set_nginx_scenario() {
    scenario_base=$1
    nginx_type=$2
    local user_listen_port=$3
    scenario=${scenario_base}_${nginx_type}
    prev_listen_port=$listen_port
    if test "$nginx_type" = "lb"; then
        set_nginx_access_log scenario/${scenario}/log/nginx/access.log
        set_nginx_error_log scenario/${scenario}/log/nginx/error.log
        set_nginx_conf "$PWD/scenario/$scenario/etc/nginx/nginx.conf"
        nginx_conf_tpl="$PWD/scenario/$scenario/etc/nginx/nginx.conf.tpl"
        listen_port=$lb_listen_port
    else
        if test -n "$user_listen_port"; then
            listen_port=$user_listen_port
        elif is_between "$listen_port" "$client_start_port" $(($client_start_port + $num_clients - 2)); then
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
    set_nginx_scenario "$scenario_base" lb
    : $(stop_nginx)

    for upstream in $(list_nginx_upstreams); do
        set_nginx_scenario "$scenario_base" client
        : $(stop_nginx)
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

function record_nginx_routing_summary() {
    local file=$(get_nginx_access_log)
    nginx_routing_summary=$(< "$file" sed 's/.*("GET[^"]+" +[0-9]+).*to:<([^>]+)>.*/\1 \2/' | uniq -c)
}

function get_nginx_routing_summary() {
    echo "$nginx_routing_summary"
}

function get_nginx_current_shard() {
    local file=$(get_nginx_access_log)
    < "$file" grep '" 200' | last_line | sed 's/.*to:<(?:[^>+]+,)?[^>]+:([^:>]+)>.*/\1/'
}

function stop_routed_nginx_client() {
    stash_nginx_scenario
    local shard=$(get_nginx_current_shard)

    if test -z "$shard"; then
        pop_nginx_scenario
        fail "Can't figure out which shard to stop"
    else
        set_nginx_scenario "$scenario_base" client $shard
        stop_nginx
        pop_nginx_scenario
        echo "    - killed shard $shard"
    fi
}

function get_nginx_routed_upstreams() {
    local file=$(get_nginx_access_log)
    < "$file" sed 's/.*to:<([^>]+)>.*/\1/'
}

function sum_consecutive_200s() {
    awk '{ if (/" 200/) {sum+=$1} else {exit} }; END{print sum}'
}

function expect_nginx_uniq_routed_upstreams() {
    local file=$(get_nginx_access_log)
    local upstreams=$(get_nginx_routed_upstreams | uniq)
    define_side_a "$upstreams"
    define_side_a_text "routing to upstream servers in nginx access log $file"
    define_addl_text "Entries:\n$upstreams"
}

function expect_nginx_routing_summary() {
    local file=$(get_nginx_access_log)
    local first_20=$(<<< "$nginx_routing_summary" head -n 20)
    define_side_a "$nginx_routing_summary"
    define_side_a_text "routing summary to upstream servers in nginx access log $file"
    define_addl_text "Routing summary (first 20 lines printed):\n${first_20}"
}
