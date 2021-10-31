import FUSD from "../../contracts/FUSD.cdc"
import FungibleToken from "../../contracts/FungibleToken.cdc"
import LedgerToken from "../../contracts/LedgerToken.cdc"
import CDToken from "../../contracts/CDToken.cdc"
import IncPool from "../../contracts/IncPool.cdc"
import IncPoolInterface from "../../contracts/IncPoolInterface.cdc"
import IncConfig from "../../contracts/IncConfig.cdc"


transaction(borrowAmount: UFix64) {

  prepare(signer: AuthAccount) {
    log("====================")
    log("user borrows:")
    let fusdStoragePath = /storage/fusdVault
    var fusdVault = signer.borrow<&FUSD.Vault>(from: fusdStoragePath)
    if fusdVault == nil {
      signer.save(<-FUSD.createEmptyVault(), to: fusdStoragePath)
      signer.link<&FUSD.Vault{FungibleToken.Receiver}>(/public/fusdReceiver, target: fusdStoragePath)
      signer.link<&FUSD.Vault{FungibleToken.Balance}>(/public/fusdBalance, target: fusdStoragePath)
    }
    fusdVault = signer.borrow<&FUSD.Vault>(from: fusdStoragePath)

    let fusdReceiver = signer.getCapability<&FUSD.Vault{FungibleToken.Receiver}>(/public/fusdReceiver)
    
    //
    let tokenVault = signer.borrow<&CDToken.Vault>(from: CDToken.VaultPath_Storage)
    assert(tokenVault != nil, message: "Lost local CDToken vault.")

    let tokenCertificate = signer.getCapability<&{LedgerToken.IdentityReceiver}>(CDToken.VaultCollateralPath_Priv)    

    log("尝试借款 FUSD ".concat(borrowAmount.toString()))
    let fusdPoolAddress: Address = IncConfig.FUSDPoolAddr
    let poolPublic = getAccount(fusdPoolAddress).getCapability<&{IncPoolInterface.PoolPublic}>(IncPool.PoolPath_Public)
    // 抵押品:
    let collaterals = [tokenCertificate]
    //
    poolPublic.borrow()!.borrow(amountUnderlyingBorrow: borrowAmount, identityCaps: collaterals, outUnderlyingVaultCap: fusdReceiver)
    //

    log("---------------------")
  }

  execute {
  }
}
