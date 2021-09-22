import FUSD from "../../contracts/FUSD.cdc"
import FungibleToken from "../../contracts/FungibleToken.cdc"
import CDToken from "../../contracts/CDToken.cdc"
import LedgerToken from "../../contracts/LedgerToken.cdc"
import IncPool from "../../contracts/IncPool.cdc"
import IncPoolInterface from "../../contracts/IncPoolInterface.cdc"
import IncConfig from "../../contracts/IncConfig.cdc"


transaction(redeemAmount: UFix64) {

  prepare(signer: AuthAccount) {
    log("====================")
    let fusdReceiver = signer.getCapability<&FUSD.Vault{FungibleToken.Receiver}>(/public/fusdReceiver)
    //
    let CDTokenPrivateCertificateCap = signer.getCapability<&{LedgerToken.PrivateCertificate}>(CDToken.VaultCollateralPath_Priv)

    log("当前ctoken数量 ".concat(CDTokenPrivateCertificateCap.borrow()!.balance.toString()))

    log("尝试取款 ".concat(redeemAmount.toString()))
    let fusdPoolAddress: Address = IncConfig.FUSDPoolAddr
    let poolPublic = getAccount(fusdPoolAddress).getCapability<&{IncPoolInterface.PoolPublic}>(IncPool.PoolPath_Public)
    poolPublic.borrow()!.redeemExplicitly(redeemOverlyingAmount: redeemAmount, collateralCap: CDTokenPrivateCertificateCap, outUnderlyingVaultCap: fusdReceiver) 
    //

    log("当前ctoken数量 ".concat(CDTokenPrivateCertificateCap.borrow()!.balance.toString()))

    log("---------------------")
  }

  execute {
  }
}
