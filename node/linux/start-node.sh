#!/bin/bash

set -e

# print current directory
echo "Current directory: $(pwd)"

# load environment variables
echo "Loading environment variables..."
source .env

# check is BIN variable set
if [ -z "$BIN" ]; then
  echo "BIN variable is not set"
  exit 1
fi

# check is BIN file exists
if [ ! -f "$BIN" ]; then
  echo "BIN file does not exist"
  exit 1
fi

# check genesis.json file exists
if [ ! -f "../genesis.json" ]; then
  echo "Genesis file does not exist"
  exit 1
fi

# 