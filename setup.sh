#!/bin/bash

modules=$(dirname "$BASH_SOURCE")/node_modules

. "$modules"/barrt/setup.sh

function count_lines() {
    wc -l | awk '{ print $1 }'
}
