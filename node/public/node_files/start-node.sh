#!/bin/bash

set -e

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <node_type>"
  exit 1
fi

NODE_TYPE=$1

if [[ "$NODE_TYPE" != "normal_node" && "$NODE_TYPE" != "seed_node" && "$NODE_TYPE" != "validator_node"
&& "$NODE_TYPE" != "snap_node" && "$NODE_TYPE" != "first_node" ]]; then
  echo "Error: Argument must be one of the following: normal_node, seed_node, snap_node, validator_node, first_node."
  exit 1
fi

case $NODE_TYPE in
    normal_node)
        echo "Running as a normal node..."
        ;;
    seed_node)
        echo "Running as a seed node..."
        ;;
    snap_node)
        echo "Running as a snap node..."
        ;;
    validator_node)
        echo "Running as a validator node..."
        ;;
    first_node)
        echo "Running as the first node..."
        ;;
    *)
        echo "Error: Invalid node type."
        exit 1
        ;;
esac

# print current directory
echo "Current directory: $(pwd)"

# load environment variables
echo "Loading environment variables..."
source .env

CONFIG="$CONF_DIR/config.toml"
APP_CONFIG="$CONF_DIR/app.toml"

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
if [ ! -f "$GENESIS_FILE" ]; then
  echo "Genesis file does not exist"
  exit 1
fi

# initialize node
if [ -z "$(ls -A $DATA_DIR)" ]; then
  echo "Initializing node..."
  $BIN init "$MONIKER" --home $DATA_DIR --chain-id $CHAIN_ID
  cp $GENESIS_FILE $DATA_DIR/config/genesis.json
fi

# modify config.toml
echo "Modifying config.toml..."
sed -i "s/moniker = \".*\"/moniker = \"$MONIKER\"/g" $CONFIG
sed -i '/laddr =/s/127.0.0.1/0.0.0.0/' $CONFIG
sed -i 's/pprof_laddr = "localhost:6060"/pprof_laddr = "0.0.0.0:6060"/g' "$CONFIG"
if [ "$NODE_TYPE" != "first_node" ]; then
  sed -i "s/seeds = \".*\"/seeds = \"$SEEDS\"/g" "$CONFIG"
  sed -i "s/persistent_peers = \".*\"/persistent_peers = \"$PERSISTENT_PEERS\"/g" "$CONFIG"
elif [ "$NODE_TYPE" == "first_node" ]; then
  sed -i "s/seeds = \".*\"/seeds = \"\"/g" "$CONFIG"
  sed -i "s/persistent_peers = \".*\"/persistent_peers = \"\"/g" "$CONFIG"
fi
if [ "$NODE_TYPE" == "seed_node" ]; then
  sed -i "s/seed_mode = false/seed_mode = true/g" "$CONFIG"
fi
if [ "$NODE_TYPE" == "normal_node" ]; then
  sed -i '/\[statesync\]/,/enable = false/s/enable = false/enable = true/' "$CONFIG"
  sed -i "s/rpc_servers = \".*\"/rpc_servers = \"$RPC_SERVERS\"/g" "$CONFIG"
  BLOCK_HEIGHT=$(curl -s $SNAP_RPC/block | jq -r .result.block.header.height | awk '{print $1 - ($1 % 1000-3)}') &&
  TRUST_HASH=$(curl -s "$SNAP_RPC/block?height=$BLOCK_HEIGHT" | jq -r .result.block_id.hash)
  sed -i "s/trust_height = 0/trust_height = $BLOCK_HEIGHT/g" "$CONFIG"
  sed -i "s/trust_hash = \"\"/trust_hash = \"$TRUST_HASH\"/g" "$CONFIG"
fi


# modify app.toml
echo "Modifying app.toml..."
sed -i.bak "s/aevmos/$DENOM_UNIT/g" $APP_CONFIG
sed -i.bak "s/uatom/$DENOM_UNIT/g" $APP_CONFIG
sed -i 's/enable-indexer = false/enable-indexer = true/g' $APP_CONFIG
perl -i -0pe 's/# Enable defines if the API server should be enabled.\nenable = false/# Enable defines if the API server should be enabled.\nenable = true/' $APP_CONFIG
sed -i 's/api = "[^"]*"/api = "web3,eth,debug,personal,net"/' "$APP_CONFIG"
sed -i 's/enabled-unsafe-cors = false/enabled-unsafe-cors = true/' "$APP_CONFIG"
sed -i 's/swagger = false/swagger = true/g' "$APP_CONFIG"
if [ "$NODE_TYPE" == "validator_node" ]; then
  sed -i 's/127.0.0.1/0.0.0.0/g' "$APP_CONFIG"
  sed -i 's/localhost/0.0.0.0/g' "$APP_CONFIG"
fi

# pruning settings
if [ "$NODE_TYPE" == "snap_node" ]; then
  sed -i 's/pruning = "default"/pruning = "nothing"/g' "$APP_CONFIG"
  sed -i 's/localhost/0.0.0.0/g' "$CONF_DIR/client.toml"
fi

# cp node_key.json and priv_validator_key.json
if [ "$NODE_TYPE" == "first_node" ]; then
  echo "Setting node_key.json and priv_validator_key.json..."
  cp node_key.json $DATA_DIR/config/node_key.json
  cp priv_validator_key.json $DATA_DIR/config/priv_validator_key.json
fi

# export node info
echo "Exporting node info..."
echo '{}' > $NODE_INFO_FILE
jq '.node_type = "'$NODE_TYPE'"' $NODE_INFO_FILE > tmp.$$.json && mv tmp.$$.json $NODE_INFO_FILE
jq '.node_id = "'$($BIN tendermint show-node-id --home $DATA_DIR)'"' $NODE_INFO_FILE > tmp.$$.json && mv tmp.$$.json $NODE_INFO_FILE

# start create validator node script
if [ "$NODE_TYPE" == "validator_node" ]; then
  nohup ./check_sync_and_create_validator.sh > /dev/null 2>&1 &
fi

# start node
echo "Starting node..."
if [ "$NODE_TYPE" == "snap_node" ]; then
  $BIN start --home $DATA_DIR --state-sync.snapshot-interval 1000 \
  --state-sync.snapshot-keep-recent 10 \
  --chain-id $CHAIN_ID \
  --keyring-backend test
elif [ "$NODE_TYPE" == "normal_node" ]; then
  LOG_FILE="$DATA_DIR/node.log"
  $BIN start --json-rpc.enable true --home $DATA_DIR --chain-id $CHAIN_ID --keyring-backend test > $LOG_FILE 2>&1 &
else
  $BIN start --json-rpc.enable true --home $DATA_DIR --chain-id $CHAIN_ID --keyring-backend test
fi