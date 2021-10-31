import FUSD from "../../contracts/FUSD.cdc"
import FungibleToken from "../../contracts/FungibleToken.cdc"
import LedgerToken from "../../contracts/LedgerToken.cdc"
import CDToken from "../../contracts/CDToken.cdc"
import IncPool from "../../contracts/IncPool.cdc"
import IncPoolInterface from "../../contracts/IncPoolInterface.cdc"
import IncConfig from "../../contracts/IncConfig.cdc"
import IncComptrollerInterface from "../../contracts/IncComptrollerInterface.cdc"


transaction(borrower: Address, repayAmount: UFix64) {

  prepare(signer: AuthAccount) {
    log("====================")
    log("清算")
    let comptrollerAddress: Address = 0xf8d6e0586b0a20c7
    let comptrollerPublicCap = getAccount(comptrollerAddress).getCapability    <&{IncComptrollerInterface.ComptrollerPublic}>    (IncConfig.Comptroller_PublicPath)
    
    let repayPoolAddr: Address = 0xf8d6e0586b0a20c7
    let seizePoolAddr: Address = 0xf8d6e0586b0a20c7
    log("repay fusd")
    log("seize fusd")

    let fusdStoragePath = /storage/fusdVault
    let fusdVault = signer.borrow<&FUSD.Vault>(from: fusdStoragePath)!
    let repayVault <- fusdVault.withdraw(amount: repayAmount)

    let outOverlyingVaultCap = signer.getCapability<&{LedgerToken.IdentityReceiver}>(CDToken.VaultCollateralPath_Priv)

    comptrollerPublicCap.borrow()!.liquidate(
      borrower: borrower,
      repayPoolAddr: repayPoolAddr,
      seizePoolAddr: seizePoolAddr,
      outOverlyingVaultCap: outOverlyingVaultCap,
      repayUnderlyingVault: <-repayVault
    )
    log("---------------------")
  }

  execute {
  }
}
