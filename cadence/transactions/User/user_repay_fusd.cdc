import FUSD from "../../contracts/FUSD.cdc"
import FungibleToken from "../../contracts/FungibleToken.cdc"
import LedgerToken from "../../contracts/LedgerToken.cdc"
import CDToken from "../../contracts/CDToken.cdc"
import IncPool from "../../contracts/IncPool.cdc"
import IncPoolInterface from "../../contracts/IncPoolInterface.cdc"
import IncConfig from "../../contracts/IncConfig.cdc"


transaction(repayAmount: UFix64) {

  prepare(signer: AuthAccount) {
    log("====================")
    let fusdStoragePath = /storage/fusdVault
    let fusdVault = signer.borrow<&FUSD.Vault>(from: fusdStoragePath)
    assert(fusdVault != nil, message: "Lost FUSD vault.")

    let borrower: Address = signer.address
    let fusdPoolAddress: Address = IncConfig.FUSDPoolAddr
    let poolPublic = getAccount(fusdPoolAddress).getCapability<&{IncPoolInterface.PoolPublic}>(IncPool.PoolPath_Public)

    var repayUnderlyingAmount = repayAmount
    if repayUnderlyingAmount == UFix64.max {
      // 当前欠款
      let curBorrow = poolPublic.borrow()!.queryBorrowBalanceRealtime(userAddr: borrower)
      repayUnderlyingAmount = curBorrow
    }
    
    //
    log("尝试还钱 ".concat(repayUnderlyingAmount.toString()))
    

    log("当前欠款".concat(poolPublic.borrow()!.queryBorrowBalanceRealtime(userAddr: borrower).toString()))

    // 还钱
    let repayVault <- fusdVault!.withdraw(amount: repayUnderlyingAmount)
    poolPublic.borrow()!.repayBorrow(repayUnderlyingVault: <-repayVault, borrowerAddr: borrower)
    
    
    log("当前欠款".concat(poolPublic.borrow()!.queryBorrowBalanceRealtime(userAddr: borrower).toString()))
    log("---------------------")
  }

  execute {
  }
}
