import FUSD from "../../contracts/FUSD.cdc"
import FungibleToken from "../../contracts/FungibleToken.cdc"
import CDToken from "../../contracts/CDToken.cdc"
import IncPool from "../../contracts/IncPool.cdc"
import LedgerToken from "../../contracts/LedgerToken.cdc"
import IncPoolInterface from "../../contracts/IncPoolInterface.cdc"
import IncConfig from "../../contracts/IncConfig.cdc"



transaction(amountDeposit: UFix64) {

  prepare(signer: AuthAccount) {
    log("====================")
    log("尝试存款 ".concat(amountDeposit.toString()))

    let fusdStoragePath = /storage/fusdVault
    var fusdVault = signer.borrow<&FUSD.Vault>(from: fusdStoragePath)
    if fusdVault == nil {
      signer.save(<-FUSD.createEmptyVault(), to: fusdStoragePath)
      signer.link<&FUSD.Vault{FungibleToken.Receiver}>(/public/fusdReceiver, target: fusdStoragePath)
      signer.link<&FUSD.Vault{FungibleToken.Balance}>(/public/fusdBalance, target: fusdStoragePath)
    }
    fusdVault = signer.borrow<&FUSD.Vault>(from: fusdStoragePath)

    assert(fusdVault!.balance >= amountDeposit, message: "No enough FUSD balance.")
    let inUnderlyingValut <-fusdVault!.withdraw(amount: amountDeposit)
    
    var overlyingVault = signer.borrow<&CDToken.Vault>(from: CDToken.VaultPath_Storage)
    if overlyingVault == nil {
      signer.save(<-CDToken.createEmptyVault(), to: CDToken.VaultPath_Storage)
      signer.link <&CDToken.Vault{FungibleToken.Receiver}>  (CDToken.VaultReceiverPath_Pub,    target: CDToken.VaultPath_Storage)
      signer.link <&{LedgerToken.PrivateCertificate}>          (CDToken.VaultCollateralPath_Priv, target: CDToken.VaultPath_Storage) 
    }
    overlyingVault = signer.borrow<&CDToken.Vault>(from: CDToken.VaultPath_Storage)
    let outOverlyingVaultCap = signer.getCapability<&{LedgerToken.PrivateCertificate}>(CDToken.VaultCollateralPath_Priv)
    

    let fusdPoolAddress: Address = IncConfig.FUSDPoolAddr
    let poolPublic = getAccount(fusdPoolAddress).getCapability<&{IncPoolInterface.PoolPublic}>(IncPool.PoolPath_Public)
    poolPublic.borrow()!.depositExplicitly(inUnderlyingVault: <-inUnderlyingValut, outOverlyingVaultCap: outOverlyingVaultCap)
    
    log("用户口袋剩余 fusd ".concat(fusdVault!.balance.toString()))
    log("用户本地ctoken数量: ".concat(overlyingVault!.balance.toString()))
    log("---------------------")
  }

  execute {
  }
}
