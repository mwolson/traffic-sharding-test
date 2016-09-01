#!/bin/bash

. $(dirname $0)/../setup.sh

describe "Load test with sharding"

set_nginx_scenario_base shard_consistent

it "starts nginx LB and clients"

start_all_nginx_instances

it "runs one-off requests to verify that multiple path patterns with same eventId are sharded together"

record_curl http://127.0.0.1:$lb_listen_port/event/a
expect_http_status; to_equal 200

record_curl http://127.0.0.1:$lb_listen_port/host/a
expect_http_status; to_equal 200

record_curl http://127.0.0.1:$lb_listen_port/host/fail
expect_http_status; to_equal 404

set_nginx_scenario $scenario_base lb
expect_nginx_uniq_routed_upstreams; to_be_consistent

reset_all_nginx_logs
expect_nginx_access_log; to_be_empty

it "runs a wrk test for 10 seconds"

inspect_next_wrk
record_wrk --latency -c 500 -t 1 -d 10s --timeout 10s http://127.0.0.1:$lb_listen_port/event/a
expect_wrk_socket_errors; to_be_empty
expect_wrk_total_requests; to_be_greater_than 1000

it "successfully routed to first available sharded upstream for test duration"

request_200s_before_termination=$(get_nginx_uniq_routed_path_status_upstreams | first_line | grep 'GET.*200' | awk '{ print $1; }')
expect_wrk_total_requests; to_be_less_than "$request_200s_before_termination"

it "stops nginx instances"

stop_all_nginx_instances
