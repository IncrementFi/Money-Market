#! /bin/bash
# 初始化fusd的ctoken
flow transactions send ./cadence/transactions/CDToken/ctoken_init_fusd.cdc --signer emulator-pool-fusd
# 创建fusd的pool
flow transactions send ./cadence/transactions/Pool/create_pool_of_fusd.cdc --signer emulator-pool-fusd
flow transactions send ./cadence/transactions/Pool/pool_apply_for_comptroller.cdc --signer emulator-pool-fusd

# 新pool的comptroller设置
flow transactions send ./cadence/transactions/Comptroller/add_pool.cdc --arg Address:0x01cf0e2f2f715450 --signer emulator-account

# +FUSD
flow transactions send ./cadence/transactions/Test/test_mint_fusd.cdc --signer emulator-user-A

