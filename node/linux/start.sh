#!/bin/bash

set -e

if [ $# -lt 1 ]; then
    echo "Error: You must pass at least one argument."
    echo "Usage: $0 <node_type> [clearOldData]"
    exit 1
fi

node_type="$1"

clearOldData="${2:-no}"

echo "Node type: $node_type"
echo "Clear old data: $clearOldData"

case $node_type in
    normal_node|seed_node|snap_node|validator_node|validator_node_2|first_node)
        ;;
    *)
        echo "Error: Invalid node type."
        exit 1
        ;;
esac

if [ -d "$node_type" ]; then
    echo "Node directory already exists."
else
    echo "Creating node directory..."
    mkdir -p $node_type
fi

if [ "$clearOldData" = "yes" ]; then
    echo "Clearing old data before starting the node..."
    rm -rf $node_type/*
fi

docker-compose up -d $node_type