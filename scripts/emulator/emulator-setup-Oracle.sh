#!/bin/bash

##### Oracle
echo "---- 1// Create oracle resource & price feeds"
echo "---- 1.1 Deploy and setup oracle resource"
flow transactions send ./cadence/transactions/Oracle/admin_create_oracle_resource.cdc --signer emulator-oracle-deployer
echo "---- 1.2 Add price feed - note: use '0x01cf0e2f2f715450' as flow pool address."
#flow transactions send ./cadence/transactions/Oracle/admin_add_price_feed.cdc --args-json '[{"type": "Address", "value": "0x01cf0e2f2f715450"}, {"type": "Int", "value": "100"}]' --signer emulator-oracle-deployer
echo "---- 1.3 Check price feeds list"
#flow scripts execute ./cadence/scripts/Oracle/get_supported_data_feeds.cdc --args-json '[{"type": "Address", "value": "0xf3fcd2c1a78f5eee"}]'
echo "---- 2// Feed data updater setup"
echo "---- 2.1 Updater setup account & admin grant role"
flow transactions send ./cadence/transactions/Oracle/updater_setup_account.cdc --signer emulator-oracle-updater
echo "---- 2.2 Admin grant updater role"
flow transactions send ./cadence/transactions/Oracle/admin_grant_update_role.cdc --args-json '[{"type": "Address", "value": "0x179b6b1cb6755e31"}]' --signer emulator-oracle-deployer
echo "---- 2.3 Check updater setup status"
flow scripts execute ./cadence/scripts/Oracle/check_updater_setup.cdc --args-json '[{"type": "Address", "value": "0x179b6b1cb6755e31"}]'
echo "---- 2.4 Updater uploads one single data point to update speficied feed"


#flow transactions send ./cadence/transactions/Oracle/updater_upload_feed_data.cdc --args-json '[{"type": "Address", "value": "0x01cf0e2f2f715450"}, {"type": "UFix64", "value": "14.15"}]' --signer emulator-oracle-updater
echo "---- 3// Check specified pool's underlying asset's latest price data,Expect to see 14.15"
#flow scripts execute ./cadence/scripts/Oracle/get_pool_underlying_price.cdc --args-json '[{"type": "Address", "value": "0xf3fcd2c1a78f5eee"}, {"type": "Address", "value": "0x01cf0e2f2f715450"}]'