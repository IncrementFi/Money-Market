import FUSD from "../../contracts/FUSD.cdc"
import FungibleToken from "../../contracts/FungibleToken.cdc"
import LedgerToken from "../../contracts/LedgerToken.cdc"
import CDToken from "../../contracts/CDToken.cdc"
import IncPool from "../../contracts/IncPool.cdc"
import IncPoolInterface from "../../contracts/IncPoolInterface.cdc"



transaction {

  prepare(signer: AuthAccount) {
    log("====================")
    log("user 增加 100.0 fusd")
    let fusdStoragePath = /storage/fusdVault
    let fusdVault = signer.borrow<&FUSD.Vault>(from: fusdStoragePath)!
    fusdVault.deposit(from: <-FUSD.test_minter.mintTokens(amount: 100.0))
    
    let gtokenVault = signer.borrow<&CDToken.Vault>(from: CDToken.VaultPath_Storage)!
    let gtokenReceiver = signer.getCapability<&{LedgerToken.PrivateCertificate}>(CDToken.VaultCollateralPath_Priv)
    

    log("尝试存款5.0")
    let fusdPoolAddress: Address = 0xf8d6e0586b0a20c7
    let poolPublic = getAccount(fusdPoolAddress).getCapability<&{IncPoolInterface.PoolPublic}>(IncPool.PoolPath_Public)
    //poolPublic.borrow()!.deposit(inUnderlyingVault: <-fusdVault.withdraw(amount: 5.0), outOverlyingVaultCap: gtokenReceiver)
    log("用户口袋剩余 fusd ".concat(fusdVault.balance.toString()))
    log("用户ctoken: ".concat(gtokenVault.balance.toString()))
    log("---------------------")
  }

  execute {
  }
}
