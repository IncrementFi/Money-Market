import FUSD from "../../contracts/FUSD.cdc"
import FungibleToken from "../../contracts/FungibleToken.cdc"
import LedgerToken from "../../contracts/LedgerToken.cdc"
import CDToken from "../../contracts/CDToken.cdc"
import IncPool from "../../contracts/IncPool.cdc"
import IncPoolInterface from "../../contracts/IncPoolInterface.cdc"



transaction {

  prepare(signer: AuthAccount) {
    log("user 增加 100.0 fusd")
    let fusdStoragePath = /storage/fusdVault
    var fusdVault = signer.borrow<&FUSD.Vault>(from: fusdStoragePath)
    if fusdVault == nil {
      signer.save(<-FUSD.createEmptyVault(), to: fusdStoragePath)
      signer.link<&FUSD.Vault{FungibleToken.Receiver}>(/public/fusdReceiver, target: fusdStoragePath)
      signer.link<&FUSD.Vault{FungibleToken.Balance}>(/public/fusdBalance, target: fusdStoragePath)
    }
    fusdVault = signer.borrow<&FUSD.Vault>(from: fusdStoragePath)
    fusdVault!.deposit(from: <-FUSD.test_minter.mintTokens(amount: 100.0))
  }

  execute {
  }
}
