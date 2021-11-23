#!/bin/bash

# flow project deploy --network testnet

# Deploy and setup oracle resource & updater role
flow transactions send cadence/transactions/Oracle/admin_create_oracle_resource.cdc --signer testnet-oracle-deployer --network testnet
# Add price feed - note: use '0x7e60df042a9c0868' as fake flow pool address.
flow transactions send cadence/transactions/Oracle/admin_add_price_feed.cdc --args-json '[{"type": "Address", "value": "0x7e60df042a9c0868"}, {"type": "Int", "value": "100"}]' --signer testnet-oracle-deployer --network testnet
# Add price feed - use '0x9a0766d93b6608b7' as fake bitcoin pool address.
flow transactions send cadence/transactions/Oracle/admin_add_price_feed.cdc --args-json '[{"type": "Address", "value": "0x9a0766d93b6608b7"}, {"type": "Int", "value": "100"}]' --signer testnet-oracle-deployer --network testnet
# Add price feed - use '0xe223d8a629e49c68' as fake ethereum pool address.
flow transactions send cadence/transactions/Oracle/admin_add_price_feed.cdc --args-json '[{"type": "Address", "value": "0xe223d8a629e49c68"}, {"type": "Int", "value": "100"}]' --signer testnet-oracle-deployer --network testnet
# Updater setup account
flow transactions send cadence/transactions/Oracle/updater_setup_account.cdc --signer testnet-oracle-updater --network testnet
# Admin grant updater role
flow transactions send cadence/transactions/Oracle/admin_grant_update_role.cdc --args-json '[{"type": "Address", "value": "0xed8eaa1512ba24aa"}]' --signer testnet-oracle-deployer --network testnet

# Check updater setup status
flow scripts execute cadence/scripts/Oracle/check_updater_setup.cdc --args-json '[{"type": "Address", "value": "0xed8eaa1512ba24aa"}]' --network testnet
# Check price feeds list
flow scripts execute cadence/scripts/Oracle/get_supported_data_feeds.cdc --args-json '[{"type": "Address", "value": "0x00bb0ede202e2a11"}]' --network testnet
# Check specified feed's latest result
flow scripts execute cadence/scripts/Oracle/get_feed_latest_result.cdc --args-json '[{"type": "Address", "value": "0x00bb0ede202e2a11"}, {"type": "Address", "value": "0x7e60df042a9c0868"}]' --network testnet
flow scripts execute cadence/scripts/Oracle/get_feed_latest_result.cdc --args-json '[{"type": "Address", "value": "0x00bb0ede202e2a11"}, {"type": "Address", "value": "0x9a0766d93b6608b7"}]' --network testnet
flow scripts execute cadence/scripts/Oracle/get_feed_latest_result.cdc --args-json '[{"type": "Address", "value": "0x00bb0ede202e2a11"}, {"type": "Address", "value": "0xe223d8a629e49c68"}]' --network testnet
