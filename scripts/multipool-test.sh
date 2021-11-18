#!/bin/bash

# deposit
flow transactions send ./cadence/transactions/User/autogen/user_deposit_FUSD.cdc -f flow_multipool.json --arg UFix64:"10.0" --signer emulator-user-A

# borrow
flow transactions send ./cadence/transactions/User/autogen/user_borrow_FUSD.cdc -f flow_multipool.json --arg UFix64:"2.0" --signer emulator-user-A

# redeem
flow transactions send ./cadence/transactions/User/autogen/user_redeem_FUSD.cdc -f flow_multipool.json --arg UFix64:"1.0" --signer emulator-user-A
# Or redeem all
# flow transactions send ./cadence/transactions/User/autogen/user_repay_Apple.cdc -f flow_multipool.json --arg UFix64:"184467440737.09551615" --signer emulator-user-A

# repay
flow transactions send ./cadence/transactions/User/autogen/user_repay_FUSD.cdc -f flow_multipool.json --arg UFix64:"2.0" --signer emulator-user-A
