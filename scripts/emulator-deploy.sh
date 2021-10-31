#!/bin/bash

### Assuming emulator is running locally

### Keys must keep as the same in the flow.json
### Do not change the order of the keys
pub_keys=(
    "99c7b442680230664baab83c4bc7cdd74fb14fb21cce3cceb962892c06d73ab9988568b8edd08cb6779a810220ad9353f8e713bc0cb8b81e06b68bcb9abb551e"
    "683a263075de8158e008badc5378a2bcbb702e194bdc2bc1a5df906a94c29a33bbc998cae3ebe87bc6338c48fcc26595130e8ffa69b65a0c0ee7f68bd82e72da"
    "A90a3acf6f891ae905092517851284ef5b25a3069ebc317eafa9a2a3808d7332c783399c7ff87f6b05b4d80a87c8def480d4de9947c56b2e59dd8e9e8e735f30"
    "9226d82be33890e8eeefe3b64dc75a68fb4a832e7ee7ec531c736cb36ab013eb08049281debac694ab106a595473b28536b6cd9ec92466ffcbb572834e291096"
    #"977d6a1a1527c1c6222252f289e02ea762e6ec7e2e29f7a36aa2da86ec11f862ddba86b27b62d86a3e203cff626794f4f87c52785ecf11c4ad5c3f26e65bb32a"
    #"7352d7e495a48a70687846d9755fb6b79888dc19a1c300808953e3475e0d352a81e22fb2b7b8ab82f781c62e4d732fbd23bb9d8493fda374e6e9366bb826bb0e"
    #"e32e93b35464a13332abea91c5292d0a41435bca12a89548c667ca2b20731394b294b9a3663b7a4a54ccead8b9d4a2df5d89127d06d529f37fb504fe048cccde"
    # Add new keys here
)
accounts=(
    "0x01cf0e2f2f715450"
    "0x179b6b1cb6755e31"
    "0xf3fcd2c1a78f5eee"
    "0xe03daebed8ca0615"
    #"0x045a1763c93006ca"
    #"0x120e725050340cab"
    #"0xf669cb8d41ce0c74"
)
for key in ${pub_keys[@]}
do
    echo $key
    flow accounts create --key $key --sig-algo "ECDSA_secp256k1"  --signer "emulator-account"
done
for addr in ${accounts[@]}
do
    echo "transfer flow token."
    flow transactions send ./cadence/Transactions/Test/emulator_flow_transfer.cdc --arg Address:$addr  --signer emulator-account
done

flow project deploy --update -f flow_env.json

flow transactions send ./cadence/Transactions/Pool/create_fusdvault_of_pool.cdc --signer emulator-pool-fusd

flow project deploy --update -f flow.json