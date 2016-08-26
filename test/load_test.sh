#!/bin/bash

. $(dirname $0)/../setup.sh

describe "Load test with sharding"

it "starts nginx"

nginx -t -g "error_log $PWD/scenario/shard_consistent/log/nginx/error.log; pid $PWD/scenario/shard_consistent/run/nginx.pid;" \
      -c $PWD/scenario/shard_consistent/etc/nginx/nginx.conf \
      2>&1 | grep -v '/var/log/nginx/error.log'
