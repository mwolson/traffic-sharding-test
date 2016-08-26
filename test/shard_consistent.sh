#!/bin/bash

. $(dirname $0)/../setup.sh

describe "Load test with sharding"

outer_scenario=shard_consistent

it "starts nginx LB"

set_scenario ${outer_scenario} lb
clear_nginx_state
render_nginx_template
start_nginx

it "starts nginx clients"

set_scenario ${outer_scenario} client
clear_nginx_state
render_nginx_template
start_nginx

# it "verifies that multiple path patterns with same eventId are sharded together"

it "stops nginx LB"

set_scenario ${outer_scenario} lb
stop_nginx

it "stops nginx clients"

set_scenario ${outer_scenario} client
stop_nginx
