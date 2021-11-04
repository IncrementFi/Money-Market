import FUSD from "../../contracts/FUSD.cdc"
import FungibleToken from "../../contracts/FungibleToken.cdc"
import LedgerToken from "../../contracts/LedgerToken.cdc"
import CDToken from "../../contracts/CDToken.cdc"
import IncPool from "../../contracts/IncPool.cdc"
import IncPoolInterface from "../../contracts/IncPoolInterface.cdc"



transaction {

  prepare(signer: AuthAccount) {
    log("====================")
    let fusdStoragePath = /storage/fusdVault
    let fusdVault = signer.borrow<&FUSD.Vault>(from: fusdStoragePath)!
    
    log("用户口袋剩余 fusd ".concat(fusdVault.balance.toString()))
    //
    log("尝试还钱 1.0")
    let fusdPoolAddress: Address = 0xf8d6e0586b0a20c7
    let borrower: Address = 0x01cf0e2f2f715450
    let poolPublic = getAccount(fusdPoolAddress).getCapability<&{IncPoolInterface.PoolPublic}>(IncPool.PoolPath_Public)
    let curBorrow = poolPublic.borrow()!.queryBorrowBalanceSnapshot(userAddr: borrower)
    log("当前欠款:".concat(curBorrow.toString()))

    // 还钱
    let repayVault <- fusdVault.withdraw(amount: 1.0)
    poolPublic.borrow()!.repayBorrow(repayUnderlyingVault: <-repayVault, borrowerAddr: borrower)
    
    
    log("当前欠款".concat(poolPublic.borrow()!.queryBorrowBalanceSnapshot(userAddr: borrower).toString()))
    log("用户口袋剩余 fusd ".concat(fusdVault.balance.toString()))
    log("---------------------")
  }

  execute {
  }
}
