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

# check is DATA_DIR exists
if [ -d "$DATA_DIR" ]; then
    # remove existing data directory
    echo "Removing existing data directory..."
    rm -rf "$DATA_DIR"
else
    echo "Creating data directory..."
fi

# create genesis.json file
echo "Creating genesis.json file..."
$BIN init "$MONIKER" --chain-id "$CHAIN_ID" --home "$DATA_DIR"

GENESIS="$DATA_DIR/config/genesis.json"
TEMP_GENESIS="$DATA_DIR/config/genesis.json.tmp"

# add wallet addresses
echo "Adding wallet addresses..."
echo "$FOUNDATION_WALLET_0" | $BIN keys add key0 --home "$DATA_DIR" --chain-id "$CHAIN_ID" --keyring-backend test --recover
echo "$FOUNDATION_WALLET_1" | $BIN keys add key1 --home "$DATA_DIR" --chain-id "$CHAIN_ID" --keyring-backend test --recover
echo "$FOUNDATION_WALLET_2" | $BIN keys add key2 --home "$DATA_DIR" --chain-id "$CHAIN_ID" --keyring-backend test --recover
echo "$FOUNDATION_WALLET_3" | $BIN keys add key3 --home "$DATA_DIR" --chain-id "$CHAIN_ID" --keyring-backend test --recover
echo "$FOUNDATION_WALLET_4" | $BIN keys add key4 --home "$DATA_DIR" --chain-id "$CHAIN_ID" --keyring-backend test --recover

# update genesis.json file
echo "Updating genesis.json file..."
sed -i.bak "s/aphoton/$DENOM_UNIT/g" $GENESIS
sed -i.bak "s/stake/$DENOM_UNIT/g" $GENESIS
sed -i.bak "s/aevmos/$DENOM_UNIT/g" $GENESIS
jq '.app_state["feemarket"]["params"]["min_gas_price"]="0.010000000000000000"' $GENESIS > "$TEMP_GENESIS" && mv "$TEMP_GENESIS" $GENESIS
jq '.consensus_params["block"]["max_gas"]="40000000"' "$GENESIS" > "$TEMP_GENESIS" && mv "$TEMP_GENESIS" "$GENESIS"
jq '.app_state["bank"]["denom_metadata"] |= . + [{"description": "The native staking token of the Vcity Chain.", "denom_units": [{"denom": "uvcity", "exponent": 0}, {"denom": "vcity", "exponent": 18}], "base": "uvcity", "display": "vcity", "name": "Vcity Token", "symbol": "VCITY"}]' $GENESIS > new_genesis.json && mv new_genesis.json $GENESIS
jq '.app_state["feemarket"]["params"]["base_fee"]="1000000000000000"' $GENESIS > "$TEMP_GENESIS" && mv "$TEMP_GENESIS" $GENESIS
sed -i.bak 's/"max_deposit_period": "172800s"/"max_deposit_period": "7200s"/g' "$GENESIS"
sed -i.bak 's/"voting_period": "172800s"/"voting_period": "7200s"/g' "$GENESIS"
jq '.app_state["gov"]["params"]["min_deposit"][0]["amount"]="10000000000000000000000"' $GENESIS > "$TEMP_GENESIS" && mv "$TEMP_GENESIS" $GENESIS
# jq '.app_state["inflation"]["params"]["inflation_distribution"]["staking_rewards"]="0.100000000000000000"' $GENESIS > "$TEMP_GENESIS" && mv "$TEMP_GENESIS" $GENESIS
# jq '.app_state["inflation"]["params"]["inflation_distribution"]["community_pool"]="0.900000000000000000"' $GENESIS > "$TEMP_GENESIS" && mv "$TEMP_GENESIS" $GENESIS
jq '.app_state["inflation"]["params"]["enable_inflation"]=false' $GENESIS > "$TEMP_GENESIS" && mv "$TEMP_GENESIS" $GENESIS
jq '.app_state["staking"]["params"]["unbonding_time"]="86400s"' $GENESIS > "$TEMP_GENESIS" && mv "$TEMP_GENESIS" $GENESIS
jq '.app_state["staking"]["params"]["max_validators"]="217"' $GENESIS > "$TEMP_GENESIS" && mv "$TEMP_GENESIS" $GENESIS
# jq '.app_state["slashing"]["params"]["slash_fraction_downtime"]="0.100000000000000000"' $GENESIS > "$TEMP_GENESIS" && mv "$TEMP_GENESIS" $GENESIS

# add genesis account
echo "Adding genesis account..."
$BIN add-genesis-account "$TEAM_WALLET_ADDRESS" 2000000000000000000000000000$DENOM_UNIT --home "$DATA_DIR"
ADDRESS_0=$($BIN keys show key0 -a --home "$DATA_DIR" --keyring-backend test)
ADDRESS_1=$($BIN keys show key1 -a --home "$DATA_DIR" --keyring-backend test)
ADDRESS_2=$($BIN keys show key2 -a --home "$DATA_DIR" --keyring-backend test)
ADDRESS_3=$($BIN keys show key3 -a --home "$DATA_DIR" --keyring-backend test)
ADDRESS_4=$($BIN keys show key4 -a --home "$DATA_DIR" --keyring-backend test)
addresses=(
    $ADDRESS_0
    $ADDRESS_1
    $ADDRESS_2
    $ADDRESS_3
)
for address in "${addresses[@]}"; do
    $BIN add-genesis-account "$address" 500000000000000000000000000$DENOM_UNIT --home "$DATA_DIR"
done
$BIN add-genesis-account "$ADDRESS_4" 6000000000000000000000000000$DENOM_UNIT --home "$DATA_DIR"

# add genesis validator
echo "Adding genesis validator..."
mkdir -p "$DATA_DIR/config/gentx"
$BIN gentx key0 200000000000000000000$DENOM_UNIT --home "$DATA_DIR" --chain-id "$CHAIN_ID" --keyring-backend test --output-document "$DATA_DIR/config/gentx/key0.json" --fees 1000000$DENOM_UNIT

# collect genesis transactions
echo "Collecting genesis transactions..."
$BIN collect-gentxs --home "$DATA_DIR"

# validate genesis file
echo "Validating genesis file..."
$BIN validate-genesis --home "$DATA_DIR"

cp $GENESIS ../genesis.json
cp $DATA_DIR/config/priv_validator_key.json ../priv_validator_key.json
cp $DATA_DIR/config/node_key.json ../node_key.json
rm -rf $DATA_DIR