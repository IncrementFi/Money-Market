#!/bin/bash -i

SignerAddrA=0xe03daebed8ca0615
SignerAddrB=0x045a1763c93006ca

SignerA=emulator-user-A
SignerB=emulator-user-B
SignerAudit=emulator-account

fusdAddr=0xff8975b2fe6fb6f1
auditAddr=0xf8d6e0586b0a20c7
# cmd
query_user_pool="flow scripts execute ./cadence/scripts/Query/query_user_pool_info.cdc"
faucet_fusd="flow transactions send ./cadence/transactions/Test/mint_fusd_for_user.cdc"
next_block="flow transactions send ./cadence/transactions/Test/test_next_block.cdc"

deposit="flow transactions send ./cadence/transactions/User/autogen/user_deposit_FUSD.cdc -f flow_multipool.json"
redeem="flow transactions send ./cadence/transactions/User/autogen/user_redeem_FUSD.cdc -f flow_multipool.json"
redeemAll="flow transactions send ./cadence/transactions/User/autogen/user_redeemAll_FUSD.cdc -f flow_multipool.json"
borrow="flow transactions send ./cadence/transactions/User/autogen/user_borrow_FUSD.cdc -f flow_multipool.json"
repay="flow transactions send ./cadence/transactions/User/autogen/user_repay_FUSD.cdc -f flow_multipool.json"
repayAll="flow transactions send ./cadence/transactions/User/autogen/user_repayAll_FUSD.cdc -f flow_multipool.json"
# test case1
eval $faucet_fusd --signer $SignerA --arg UFix64:"100.0"
eval $faucet_fusd --signer $SignerB --arg UFix64:"1999999999.09999999"

eval $deposit --signer $SignerA --arg UFix64:"10.0"
eval $deposit --signer $SignerB --arg UFix64:"999999999.09999999"

eval $borrow --signer $SignerB --arg UFix64:"699999999.0"
eval $borrow --signer $SignerA --arg UFix64:"1.0"
#eval $repayAll --signer $SignerA
#eval $redeemAll --signer $SignerA

eval $next_block --signer $SignerAudit
eval $next_block --signer $SignerAudit
eval $next_block --signer $SignerAudit



eval $query_user_pool $SignerAddrA $fusdAddr $auditAddr

#eval $redeem --signer $SignerA --arg UFix64:"5.0"


#flow scripts execute ./cadence/scripts/Query/query_user_pool_info.cdc $userA $fusdAddr $auditAddr

# borrow
#flow transactions send ./cadence/transactions/User/autogen/user_borrow_FUSD.cdc -f flow_multipool.json --arg UFix64:"2.0" --signer emulator-user-A



# redeem
#flow transactions send ./cadence/transactions/User/autogen/user_redeem_FUSD.cdc -f flow_multipool.json --arg UFix64:"1.0" --signer emulator-user-A
# Or redeem all
# flow transactions send ./cadence/transactions/User/autogen/user_repay_Apple.cdc -f flow_multipool.json --arg UFix64:"184467440737.09551615" --signer emulator-user-A

# repay
#flow transactions send ./cadence/transactions/User/autogen/user_repay_FUSD.cdc -f flow_multipool.json --arg UFix64:"184467440737.09551615" --signer emulator-user-A
