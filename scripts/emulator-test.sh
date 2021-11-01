#! /bin/bash
# deposit
flow transactions send ./cadence/transactions/User/user_deposit_fusd.cdc --arg UFix64:"10.0" --signer emulator-user-A

# borrow
flow transactions send ./cadence/transactions/User/user_borrow_fusd.cdc --arg UFix64:"10.0" --signer emulator-user-A

# redeem
# flow transactions send ./cadence/transactions/User/user_redeem_fusd.cdc --arg UFix64:"1.0" --signer emulator-user-A
# redeem all
# flow transactions send ./cadence/transactions/User/user_repay_fusd.cdc --arg UFix64:"184467440737.09551615" --signer emulator-user-A

# repay
flow transactions send ./cadence/transactions/User/user_repay_fusd.cdc --arg UFix64:"2.0" --signer emulator-user-A
