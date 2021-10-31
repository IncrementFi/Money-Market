#! /bin/bash
echo "Test deposit"
flow transactions send ./cadence/transactions/User/user_deposit_fusd.cdc --arg UFix64:"5.0" --signer emulator-user-A

# 借款
#flow transactions send ./cadence/transactions/User/user_borrow_fusd.cdc --arg UFix64:"2.0" --signer emulator-user-A
# 取款
#flow transactions send ./cadence/transactions/User/user_redeem_fusd.cdc --arg UFix64:"1.0" --signer emulator-user-A
# 还款
#flow transactions send ./cadence/transactions/User/user_repay_fusd.cdc --arg UFix64:"184467440737.09551615" --signer emulator-user-A
