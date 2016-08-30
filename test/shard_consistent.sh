#!/bin/bash

. $(dirname $0)/../setup.sh

describe "Load test with sharding"

outer_scenario=shard_consistent

it "starts nginx LB"

set_nginx_scenario ${outer_scenario} lb
clear_nginx_state
render_nginx_template
start_nginx

it "starts nginx clients"

for upstream in $(list_upstreams); do
    set_nginx_scenario ${outer_scenario} client
    clear_nginx_state
    render_nginx_template
    start_nginx
done

it "verifies that multiple path patterns with same eventId are sharded together"

record_curl http://127.0.0.1:$lb_listen_port/event/a
expect_http_status; to_equal 200

record_curl http://127.0.0.1:$lb_listen_port/host/a
expect_http_status; to_equal 200

record_curl http://127.0.0.1:$lb_listen_port/host/fail
expect_http_status; to_equal 404

set_nginx_scenario ${outer_scenario} lb
expect_nginx_access_log; to_not_be_empty

reset_all_nginx_logs
expect_nginx_access_log; to_be_empty

it "stops nginx LB"

set_nginx_scenario ${outer_scenario} lb
stop_nginx

it "stops nginx clients"

for upstream in $(list_upstreams); do
    set_nginx_scenario ${outer_scenario} client
    stop_nginx
done
