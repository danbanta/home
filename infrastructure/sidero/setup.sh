#!/usr/bin/env bash

export HOST_IP="172.16.116.150"

talosctl cluster create \
    --name sidero-demo \
    -p 69:69/udp,8081:8081/tcp,51821:51821/udp \
    --workers 0 \
    --config-patch '[{"op": "add", "path": "/cluster/allowSchedulingOnMasters", "value": true}]' \
    --endpoint $HOST_IP
