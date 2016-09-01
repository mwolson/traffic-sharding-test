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

it "runs a wrk test for 10 seconds, stopping current nginx clients after 2 and 4 seconds"

in_n_seconds 2 stop_routed_nginx_client
in_n_seconds 4 stop_routed_nginx_client

inspect_next_wrk

if on_os_x; then
    # don't try to reuse connections, since there's an issue with OS X kqueue bombing when a shard is brought down
    record_wrk --latency -H "Connection: close" \
        -c "$wrk_connections" -t 1 -d 10s --timeout 10s http://127.0.0.1:$lb_listen_port/event/a
else
    record_wrk --latency -c "$wrk_connections" -t 1 -d 10s --timeout 10s http://127.0.0.1:$lb_listen_port/event/a
fi

expect_wrk_total_requests; to_be_greater_than 1000

it "had no socket errors"

if ! on_os_x; then
    expect_wrk_socket_errors; to_be_empty
fi

expect_wrk_failed_requests; to_be_empty

it "successfully routed to an available sharded upstream for entire duration of test"

record_nginx_routing_summary
request_200s_before_termination=$(get_nginx_routing_summary | sum_consecutive_200s)
expect_wrk_total_requests; to_be_less_than_or_equal_to "$request_200s_before_termination"

it "occasionally retried all downed shards"

expect_nginx_routing_summary; to_match "200 127.0.0.1:[0-9]+, 127.0.0.1:[0-9]+, 127.0.0.1:[0-9]+"

it "stops nginx instances"

stop_all_nginx_instances
