#!/bin/bash -i

SignerAddrA=0xe03daebed8ca0615
SignerAddrB=0x045a1763c93006ca
SignerAddrC=0x120e725050340cab
SignerAddrD=0xf669cb8d41ce0c74

SignerA=emulator-user-A
SignerB=emulator-user-B
SignerC=emulator-user-C
SignerD=emulator-user-D
SignerAudit=emulator-account

fusdPoolAddr=0x192440c99cb17282
fETHPoolAddr=0x0f7025fa05b578e3
auditAddr=0xf8d6e0586b0a20c7



# cmd
query_user_pool="flow scripts execute ./cadence/scripts/Query/query_user_pool_info.cdc"
query_user_pools="flow scripts execute ./cadence/scripts/Query/query_user_pool_infos.cdc 0x045a1763c93006ca 0xf8d6e0586b0a20c7"
#flow scripts execute ./cadence/scripts/Query/query_market_info.cdc 0x0f7025fa05b578e3 0xf8d6e0586b0a20c7
query_user_position="flow scripts execute ./cadence/scripts/Query/query_user_position.cdc"

faucet_Flow="flow transactions send ./cadence/transactions/Test/emulator_flow_transfer.cdc --signer emulator-account -f flow_multipool.json"
faucet_fusd="flow transactions send ./cadence/transactions/Test/mint_fusd_for_user.cdc -f flow_multipool.json"
faucet_fETH="flow transactions send ./cadence/transactions/Test/autogen/mint_FETH_for_user.cdc -f flow_multipool.json"
faucet_fBTC="flow transactions send ./cadence/transactions/Test/autogen/mint_FBTC_for_user.cdc -f flow_multipool.json"
next_block="flow transactions send ./cadence/transactions/Test/test_next_block.cdc"

depositFUSD="flow transactions send ./cadence/transactions/User/autogen/user_deposit_FUSD.cdc -f flow_multipool.json"
redeemFUSD="flow transactions send ./cadence/transactions/User/autogen/user_redeem_FUSD.cdc -f flow_multipool.json"
borrowFUSD="flow transactions send ./cadence/transactions/User/autogen/user_borrow_FUSD.cdc -f flow_multipool.json"
repayFUSD="flow transactions send ./cadence/transactions/User/autogen/user_repay_FUSD.cdc -f flow_multipool.json"

depositFETH="flow transactions send ./cadence/transactions/User/autogen/user_deposit_FETH.cdc -f flow_multipool.json"
redeemFETH="flow transactions send ./cadence/transactions/User/autogen/user_redeem_FETH.cdc -f flow_multipool.json"
borrowFETH="flow transactions send ./cadence/transactions/User/autogen/user_borrow_FETH.cdc -f flow_multipool.json"
repayFETH="flow transactions send ./cadence/transactions/User/autogen/user_repay_FETH.cdc -f flow_multipool.json"

updateOracle="flow transactions send ./cadence/transactions/Oracle/updater_upload_feed_data.cdc -f flow_multipool.json"
# faucet userA
eval $faucet_fETH --signer $SignerA --arg UFix64:"1.0"
# faucet userB
eval $faucet_fusd --signer $SignerB --arg UFix64:"100000.0"
eval $faucet_fETH --signer $SignerB --arg UFix64:"10.0"
# faucet userC
eval $faucet_fETH --signer $SignerC --arg UFix64:"2.0"
# faucet userD
eval $faucet_fusd --signer $SignerD --arg UFix64:"50000.0"

# supply userA
eval $depositFETH --signer $SignerA --arg UFix64:"1.0"
eval $depositFETH --signer $SignerC --arg UFix64:"1.0"
# supply userD
eval $depositFUSD --signer $SignerD --arg UFix64:"50000.0"

# borrow userA
eval $borrowFUSD --signer $SignerA --arg UFix64:"3000.0"
eval $borrowFUSD --signer $SignerC --arg UFix64:"3200.0"

eval $updateOracle --signer emulator-oracle-updater --arg Address:$fETHPoolAddr --arg UFix64:"3500.0"
# oracle update
# flow transactions send ./cadence/transactions/Oracle/updater_upload_feed_data.cdc -f flow_multipool.json --signer emulator-oracle-updater --arg Address:0x0f7025fa05b578e3 --arg UFix64:"3400.0"

# borrow
#flow transactions send ./cadence/transactions/User/autogen/user_borrow_FETH.cdc -f flow_multipool.json --signer emulator-user-A --arg UFix64:"10.0"

#eval $next_block --signer $SignerAudit

#eval $query_user_pool $SignerAddrA $fusdPoolAddr $auditAddr
#eval $query_user_pool $SignerAddrA $fETHPoolAddr $auditAddr

#eval $query_user_position $SignerAddrA $auditAddr
