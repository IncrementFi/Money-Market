#!/bin/bash -i

SignerAddrA=0xe03daebed8ca0615
SignerAddrB=0x045a1763c93006ca

SignerA=emulator-user-A
SignerB=emulator-user-B
SignerAudit=emulator-account

fusdPoolAddr=0x192440c99cb17282
applePoolAddr=0xeb179c27144f783c
auditAddr=0xf8d6e0586b0a20c7



# cmd
query_user_pool="flow scripts execute ./cadence/scripts/Query/query_user_pool_info.cdc"
query_user_position="flow scripts execute ./cadence/scripts/Query/query_user_position.cdc"

faucet_fusd="flow transactions send ./cadence/transactions/Test/mint_fusd_for_user.cdc"
faucet_apple="flow transactions send ./cadence/transactions/Test/autogen/mint_Apple_for_user.cdc -f flow_multipool.json"
next_block="flow transactions send ./cadence/transactions/Test/test_next_block.cdc"

depositFUSD="flow transactions send ./cadence/transactions/User/autogen/user_deposit_FUSD.cdc -f flow_multipool.json"
redeemFUSD="flow transactions send ./cadence/transactions/User/autogen/user_redeem_FUSD.cdc -f flow_multipool.json"
borrowFUSD="flow transactions send ./cadence/transactions/User/autogen/user_borrow_FUSD.cdc -f flow_multipool.json"
repayFUSD="flow transactions send ./cadence/transactions/User/autogen/user_repay_FUSD.cdc -f flow_multipool.json"

depositApple="flow transactions send ./cadence/transactions/User/autogen/user_deposit_Apple.cdc -f flow_multipool.json"
redeemApple="flow transactions send ./cadence/transactions/User/autogen/user_redeem_Apple.cdc -f flow_multipool.json"
borrowApple="flow transactions send ./cadence/transactions/User/autogen/user_borrow_Apple.cdc -f flow_multipool.json"
repayApple="flow transactions send ./cadence/transactions/User/autogen/user_repay_Apple.cdc -f flow_multipool.json"

updateOracle="flow transactions send ./cadence/transactions/Oracle/updater_upload_feed_data.cdc -f flow_multipool.json"
# test case1
eval $faucet_fusd --signer $SignerA --arg UFix64:"1000.0"
eval $faucet_apple --signer $SignerB --arg UFix64:"1000.0"

eval $depositFUSD --signer $SignerA --arg UFix64:"1000.0"
eval $depositApple --signer $SignerB --arg UFix64:"1000.0"

eval $borrowApple --signer $SignerA --arg UFix64:"80.0"

eval $updateOracle --signer emulator-oracle-updater --arg Address:$applePoolAddr --arg UFix64:"11.0"

#flow transactions send ./cadence/transactions/User/autogen/user_borrow_Apple.cdc -f flow_multipool.json --signer emulator-user-A --arg UFix64:"10.0"

#eval $next_block --signer $SignerAudit


eval $query_user_pool $SignerAddrA $fusdPoolAddr $auditAddr
eval $query_user_pool $SignerAddrA $applePoolAddr $auditAddr

eval $query_user_position $SignerAddrA $auditAddr
#flow scripts execute ./cadence/scripts/Query/query_user_position.cdc 0xe03daebed8ca0615 0xf8d6e0586b0a20c7

#eval $redeemFUSD --signer $SignerA --arg UFix64:"5.0"
