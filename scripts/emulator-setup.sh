#! /bin/bash
# 初始化fusd的ctoken
flow transactions send ./cadence/transactions/CDToken/ctoken_init_fusd.cdc --signer emulator-account
# 创建fusd的pool
flow transactions send ./cadence/transactions/Pool/create_pool_of_fusd.cdc --signer emulator-account
flow transactions send ./cadence/transactions/Pool/pool_apply_for_comptroller.cdc --signer emulator-account

# 新pool的comptroller设置
flow transactions send ./cadence/transactions/Comptroller/add_pool.cdc --arg Address:0xf8d6e0586b0a20c7 --signer emulator-account

# +FUSD
flow transactions send ./cadence/transactions/Test/test_mint_fusd.cdc --signer emulatorA

