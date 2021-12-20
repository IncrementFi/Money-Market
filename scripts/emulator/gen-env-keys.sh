#!/bin/bash

### Assuming emulator is running locally

keys=$(flow keys generate --sig-algo "ECDSA_secp256k1" -o json)
publicKey=$(echo $keys | jq ".public" -r)
privateKey=$(echo $keys | jq ".private" -r)

account=$(flow accounts create --key $publicKey --sig-algo "ECDSA_secp256k1" --signer "emulator-account"  -o json)
address=$(echo $account | jq ".address" -r)

cat << EOF
"$name" : {
  "address": "$address",
  "privateKey": "$privateKey",
  "publicKey": "$publicKey",
  "sig-algo": "ECDSA_secp256k1",
  "chain": "flow-emulator"
}
EOF
