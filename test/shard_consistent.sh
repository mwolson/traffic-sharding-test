#!/bin/bash

. $(dirname $0)/../setup.sh

describe "Load test with sharding"

set_scenario shard_consistent

it "starts nginx"

render_nginx_template
check_nginx_conf
