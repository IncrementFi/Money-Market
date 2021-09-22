#! /bin/bash
# 存款
flow transactions send ./cadence/transactions/User/user_deposit_fusd.cdc --arg UFix64:"5.0" --signer emulatorA
# 借款
flow transactions send ./cadence/transactions/User/user_borrow_fusd.cdc --arg UFix64:"2.0" --signer emulatorA
# 取款
flow transactions send ./cadence/transactions/User/user_redeem_fusd.cdc --arg UFix64:"1.0" --signer emulatorA
# 还款
flow transactions send ./cadence/transactions/User/user_repay_fusd.cdc --arg UFix64:"184467440737.09551615" --signer emulatorA
