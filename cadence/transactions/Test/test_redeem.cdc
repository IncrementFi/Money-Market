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
    let fusdReceiver = signer.getCapability<&FUSD.Vault{FungibleToken.Receiver}>(/public/fusdReceiver)
    
    //
    let gtokenVault = signer.borrow<&CDToken.Vault>(from: CDToken.VaultPath_Storage)!
    let gtokenReceiver = signer.getCapability<&CDToken.Vault{FungibleToken.Receiver}>(CDToken.VaultReceiverPath_Pub)
    log("当前ctoken数量 ".concat(gtokenVault.balance.toString()))
    //let inOverlyingVault <- gtokenVault.withdraw(amount: 2.0)

    log("尝试取款 2.0")
    let fusdPoolAddress: Address = 0xf8d6e0586b0a20c7
    let poolPublic = getAccount(fusdPoolAddress).getCapability<&{IncPoolInterface.PoolPublic}>(IncPool.PoolPath_Public)
    //poolPublic.borrow()!.redeem(inOverlyingVault: <-inOverlyingVault, outUnderlyingVaultCap: fusdReceiver)
    //


    log("用户口袋剩余 fusd ".concat(fusdVault.balance.toString()))
    log("用户ctoken: ".concat(gtokenVault.balance.toString()))
    log("---------------------")
  }

  execute {
  }
}
