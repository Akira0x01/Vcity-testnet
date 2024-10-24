#!/bin/bash

set -e

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

# add wallet addresses
echo "Adding wallet addresses..."
echo "$VALIDATOR_WALLET" | $BIN keys add validator --home "$DATA_DIR" --chain-id "$CHAIN_ID" --keyring-backend test --recover

LOG_FILE="$DATA_DIR/create_validator.log"
STAKE_AMOUNT="100000000000000000000"
PUB_KEY="$($BIN tendermint show-validator --home $DATA_DIR)"
MONIKER="vcity-validator"

VALIDATOR_CMD="$BIN tx staking create-validator \
  --amount $STAKE_AMOUNT$DENOM_UNIT \
  --pubkey $PUB_KEY \
  --moniker $MONIKER \
  --chain-id $CHAIN_ID \
  --commission-rate 0.05 \
  --commission-max-rate 0.10 \
  --commission-max-change-rate 0.01 \
  --min-self-delegation 99000000000000000000$DENOM_UNIT \
  --gas auto \
  --gas-prices 100$DENOM_UNIT \
  --from validator \
  --keyring-backend test \
  --home $DATA_DIR \
  --yes
"

if [ -f "$LOG_FILE" ]; then
  echo "Validator creation log file exists."
  break
else
  echo "Validator creation log file does not exist."
  echo "Creating validator..."
  $VALIDATOR_CMD > $LOG_FILE
fi

while true; do
  catching_up=$($BIN status --home $DATA_DIR | jq -r '.SyncInfo.catching_up')

  echo "$(date) - Checking if the node is catching up..." >> $LOG_FILE
  echo "Catching up: $catching_up" >> $LOG_FILE

    if [ "$catching_up" = "false" ]; then
        echo "$(date) - Node is synced. Creating validator..." >> $LOG_FILE
        eval $VALIDATOR_CMD >> $LOG_FILE 2>$1
        echo "$(date) - Validator creation command executed. Exiting loop..." >> $LOG_FILE
        break
    else
        echo "$(date) - Node is not synced. Waiting for 1 minute." >> $LOG_FILE
    fi

    sleep 60
done

echo "$(date) - Validator creation process completed." >> $LOG_FILE

