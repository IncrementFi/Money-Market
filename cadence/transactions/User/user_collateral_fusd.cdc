import FUSD from "../../contracts/FUSD.cdc"
import FungibleToken from "../../contracts/FungibleToken.cdc"
import CDToken from "../../contracts/CDToken.cdc"
import IncPool from "../../contracts/IncPool.cdc"
import LedgerToken from "../../contracts/LedgerToken.cdc"
import IncPoolInterface from "../../contracts/IncPoolInterface.cdc"
import IncConfig from "../../contracts/IncConfig.cdc"


// 用户开启该Pool作为抵押物
transaction(ifCollateral: Bool) {

  prepare(signer: AuthAccount) {
    log("====================")
    log("开关抵押品")
    
    if ifCollateral == true {
      // 首次在本地创建overlying vault
      if signer.borrow<&CDToken.Vault>(from: CDToken.VaultPath_Storage) == nil {
        signer.save(<-CDToken.createEmptyVault(), to: CDToken.VaultPath_Storage)
        signer.link <&CDToken.Vault{FungibleToken.Receiver}>  (CDToken.VaultReceiverPath_Pub,    target: CDToken.VaultPath_Storage)
        signer.link <&{LedgerToken.IdentityReceiver}>          (CDToken.VaultCollateralPath_Priv, target: CDToken.VaultPath_Storage) 
      }
    }

    let identityCap = signer.getCapability<&{LedgerToken.IdentityReceiver}>(CDToken.VaultCollateralPath_Priv)
    
    let fusdPoolAddress: Address = IncConfig.FUSDPoolAddr
    let poolPublic = getAccount(fusdPoolAddress).getCapability<&{IncPoolInterface.PoolPublic}>(IncPool.PoolPath_Public)
    poolPublic.borrow()!.openCollateral(open: ifCollateral, identityCap: identityCap)
    log("---------------------")
  }

  execute {
  }
}
