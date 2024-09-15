#!/bin/bash

set -e

HOST=1.1.1.1
PORT_SEQUENCE="7000 8000 9000"
DELAY=0.2

for port in $PORT_SEQUENCE; do
    echo -n hello > /dev/udp/$HOST/$port
    sleep $DELAY
done

