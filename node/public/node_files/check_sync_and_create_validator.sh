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

# export validator info
echo "Exporting validator info..."
acc_address=$($BIN keys show validator --bech acc -a --home $DATA_DIR --keyring-backend test)
val_address=$($BIN keys show validator --bech val -a --home $DATA_DIR --keyring-backend test)
cons_address=$($BIN keys show validator --bech cons -a --home $DATA_DIR --keyring-backend test)
hex_address=$($BIN debug addr $acc_address | grep -oP "0x[A-Fa-f0-9]+")
jq '.acc_address = "'$acc_address'"' $NODE_INFO_FILE > tmp.$$.json && mv tmp.$$.json $NODE_INFO_FILE
jq '.val_address = "'$val_address'"' $NODE_INFO_FILE > tmp.$$.json && mv tmp.$$.json $NODE_INFO_FILE
jq '.cons_address = "'$cons_address'"' $NODE_INFO_FILE > tmp.$$.json && mv tmp.$$.json $NODE_INFO_FILE
jq '.hex_address = "'$hex_address'"' $NODE_INFO_FILE > tmp.$$.json && mv tmp.$$.json $NODE_INFO_FILE

LOG_FILE="$DATA_DIR/create_validator.log"
STAKE_AMOUNT="100000000000000000000"
MONIKER="vcity-validator"

touch $LOG_FILE

# VALIDATOR_CMD="$BIN tx staking create-validator \
#   --amount=$STAKE_AMOUNT$DENOM_UNIT \
#   --pubkey=$($BIN tendermint show-validator --home $DATA_DIR --chain-id $CHAIN_ID) \
#   --moniker=$MONIKER \
#   --chain-id=$CHAIN_ID \
#   --commission-rate="0.05" \
#   --commission-max-rate="0.10" \
#   --commission-max-change-rate="0.01" \
#   --min-self-delegation="99000000000000000000" \
#   --gas=auto \
#   --gas-prices="100$DENOM_UNIT" \
#   --from=validator \
#   --keyring-backend=test \
#   --home=$DATA_DIR \
#   --yes
# "

if [ -f "$LOG_FILE" ]; then
  echo "Validator creation log file exists."
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
        echo "Validator creation command: $VALIDATOR_CMD" >> $LOG_FILE
        # eval $VALIDATOR_CMD >> $LOG_FILE 2>&1
        $BIN tx staking create-validator \
          --amount=$STAKE_AMOUNT$DENOM_UNIT \
          --pubkey=$($BIN tendermint show-validator --home $DATA_DIR --chain-id $CHAIN_ID) \
          --moniker=$MONIKER \
          --chain-id=$CHAIN_ID \
          --commission-rate="0.05" \
          --commission-max-rate="0.10" \
          --commission-max-change-rate="0.01" \
          --min-self-delegation="99000000000000000000" \
          --gas=auto \
          --gas-prices="100$DENOM_UNIT" \
          --from=validator \
          --keyring-backend=test \
          --home=$DATA_DIR \
          --yes \
          >> $LOG_FILE 2>&1
        echo "$(date) - Validator creation command executed. Exiting loop..." >> $LOG_FILE
        break
    else
        echo "$(date) - Node is not synced. Waiting for 1 minute." >> $LOG_FILE
    fi

    sleep 60
done

echo "$(date) - Validator creation process completed." >> $LOG_FILE

