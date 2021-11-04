#!/bin/bash

# 初始化fusd的ctoken
#flow transactions send ./cadence/transactions/CDToken/ctoken_init_fusd.cdc --signer emulator-pool-fusd
# 创建fusd的pool
#flow transactions send ./cadence/transactions/Pool/create_pool_of_fusd.cdc --signer emulator-pool-fusd
#flow transactions send ./cadence/transactions/Pool/pool_apply_for_comptroller.cdc --signer emulator-pool-fusd

# 新pool的comptroller设置
#flow transactions send ./cadence/transactions/Comptroller/add_pool.cdc --arg Address:0x01cf0e2f2f715450 --signer emulator-account


##### Interest Rate Model
echo "---- 1// Create InterestRateModel resource"
flow transactions send cadence/transactions/InterestRateModel/create_interest_rate_model.cdc --args-json '[{"type": "String", "value": "TwoSegmentsInterestRateModel"}, {"type": "UInt64", "value": "315360"}, {"type": "UFix64", "value": "0.0"}, {"type": "UFix64", "value": "0.05"}, {"type": "UFix64", "value": "0.35"}, {"type": "UFix64", "value": "0.8"}]' --signer emulator-account
echo "---- 2// Check model parameters:"
flow scripts execute cadence/scripts/InterestRateModel/get_model_params.cdc --args-json '[{"type": "Address", "value": "0xf8d6e0586b0a20c7"}]'


##### Oracle
echo "---- 1// Create oracle resource & price feeds"
echo "---- 1.1 Deploy and setup oracle resource"
flow transactions send cadence/transactions/Oracle/admin_create_oracle_resource.cdc --signer emulator-oracle-deployer
echo "---- 1.2 Add price feed - note: use '0x01cf0e2f2f715450' as fusd pool address."
flow transactions send cadence/transactions/Oracle/admin_add_price_feed.cdc --args-json '[{"type": "Address", "value": "0x01cf0e2f2f715450"}, {"type": "Int", "value": "100"}]' --signer emulator-oracle-deployer
echo "---- 1.3 Check price feeds list"
flow scripts execute cadence/scripts/Oracle/get_supported_data_feeds.cdc --args-json '[{"type": "Address", "value": "0xf3fcd2c1a78f5eee"}]'
echo "---- 2// Feed data updater setup"
echo "---- 2.1 Updater setup account & admin grant role"
flow transactions send cadence/transactions/Oracle/updater_setup_account.cdc --signer emulator-oracle-updater
echo "---- 2.2 Admin grant updater role"
flow transactions send cadence/transactions/Oracle/admin_grant_update_role.cdc --args-json '[{"type": "Address", "value": "0xe03daebed8ca0615"}]' --signer emulator-oracle-deployer
echo "---- 2.3 Check updater setup status"
flow scripts execute cadence/scripts/Oracle/check_updater_setup.cdc --args-json '[{"type": "Address", "value": "0xe03daebed8ca0615"}]'
echo "---- 2.4 Updater uploads one single data point to update speficied feed"
flow transactions send cadence/transactions/Oracle/updater_upload_feed_data.cdc --args-json '[{"type": "Address", "value": "0x01cf0e2f2f715450"}, {"type": "UFix64", "value": "1.005"}]' --signer emulator-oracle-updater
echo "---- 3// Check specified pool's underlying asset's latest price data,Expect to see 1.005"
flow scripts execute cadence/scripts/Oracle/get_pool_underlying_price.cdc --args-json '[{"type": "Address", "value": "0xf3fcd2c1a78f5eee"}, {"type": "Address", "value": "0x01cf0e2f2f715450"}]'

#### Init FUSD Pool
echo "---- Init pool of FUSD"
flow transactions send ./cadence/transactions/Pool/init_pool_fusd.cdc --signer emulator-pool-fusd

### Init Comptroller
echo "---- Init Comptroller"
flow transactions send ./cadence/transactions/Comptroller/init_comptroller.cdc --signer emulator-account

### Add FUSD Pool in comptroller
echo "---- Add market of FUSD to comptroller"
flow transactions send ./cadence/transactions/Comptroller/add_market.cdc --arg Address:0x01cf0e2f2f715450 --arg UFix64:0.75 --arg UFix64:100.0 --arg Bool:true --arg Bool:true --signer emulator-account

#### Test Account Preparations
echo '---- Mint fusd for userA'
flow transactions send ./cadence/transactions/Test/test_mint_fusd.cdc --signer emulator-user-A

