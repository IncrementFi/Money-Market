import FUSD from "../../contracts/FUSD.cdc"
import FungibleToken from "../../contracts/FungibleToken.cdc"
import LedgerToken from "../../contracts/LedgerToken.cdc"
// TODO 同一份CDToken会部署在多个地址, 这里需要根据需要修改合约地址
import CDToken from "../../contracts/CDToken.cdc"


transaction {

  prepare(signer: AuthAccount) {
    log("====================")
    log("user 创建本地FUSD vault")
    let fusdStoragePath = /storage/fusdVault
    if signer.borrow<&FUSD.Vault>(from: fusdStoragePath) == nil {
      signer.save(<-FUSD.createEmptyVault(), to: fusdStoragePath)
    }
    signer.link<&FUSD.Vault{FungibleToken.Receiver}>(/public/fusdReceiver, target: fusdStoragePath)
    signer.link<&FUSD.Vault{FungibleToken.Balance}>(/public/fusdBalance, target: fusdStoragePath)

    log("user 创建本地CDToken vault")
    if signer.borrow<&CDToken.Vault>(from: CDToken.VaultPath_Storage) == nil {
      signer.save(<-CDToken.createEmptyVault(), to: CDToken.VaultPath_Storage)
    }
    // 这抵押interface必须放在private，作为用户抵押认证使用, 这个cap非常重要
    signer.link <&CDToken.Vault{FungibleToken.Receiver}>  (CDToken.VaultReceiverPath_Pub,    target: CDToken.VaultPath_Storage)
    signer.link <&{LedgerToken.IdentityReceiver}>               (CDToken.VaultCollateralPath_Priv, target: CDToken.VaultPath_Storage) 

    log("---------------------")
  }

  execute {
  }
}
