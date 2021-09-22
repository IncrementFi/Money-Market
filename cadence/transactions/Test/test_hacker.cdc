import FUSD from "../../contracts/FUSD.cdc"
import FungibleToken from "../../contracts/FungibleToken.cdc"
import LedgerToken from "../../contracts/LedgerToken.cdc"
import CDToken from "../../contracts/CDToken.cdc"
import IncPool from "../../contracts/IncPool.cdc"
import IncPoolInterface from "../../contracts/IncPoolInterface.cdc"



transaction {

  prepare(signer: AuthAccount) {
    log("====================")
    log("黑客测试")

    let overlyingVault = signer.borrow<&CDToken.Vault>(from: CDToken.VaultPath_Storage)!
    let overlyingReceiver = signer.getCapability<&CDToken.Vault{FungibleToken.Receiver}>(CDToken.VaultReceiverPath_Pub)
    //log("故意取消cap")
    //signer.unlink(CDToken.VaultReceiverPath_Pub)

    log("替换overlying vault")
    let preVault <- signer.load<@CDToken.Vault>(from: CDToken.VaultPath_Storage)
    destroy preVault
    signer.save(<-CDToken.createEmptyVault(), to: CDToken.VaultPath_Storage)
    //signer.link <&CDToken.Vault{FungibleToken.Receiver}>  (CDToken.VaultReceiverPath_Pub,    target: CDToken.VaultPath_Storage)
    
    log("---------------------")
  }

  execute {
  }
}
