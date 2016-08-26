#!/bin/bash

. $(dirname $0)/../setup.sh

describe "Load test with sharding"

set_scenario shard_consistent

it "starts nginx"

render_nginx_template
start_nginx

it "stops nginx"

stop_nginx
