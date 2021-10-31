import FUSD from "../../contracts/FUSD.cdc"
import FungibleToken from "../../contracts/FungibleToken.cdc"

transaction {

  prepare(signer: AuthAccount) {
    log("Transaction Start ---------------")
    log("user add 100.0 fusd")
    let fusdStoragePath = /storage/fusdVault
    var fusdVault = signer.borrow<&FUSD.Vault>(from: fusdStoragePath)
    if fusdVault == nil {
      signer.save(<-FUSD.createEmptyVault(), to: fusdStoragePath)
      signer.link<&FUSD.Vault{FungibleToken.Receiver}>(/public/fusdReceiver, target: fusdStoragePath)
      signer.link<&FUSD.Vault{FungibleToken.Balance}>(/public/fusdBalance, target: fusdStoragePath)
    }
    fusdVault = signer.borrow<&FUSD.Vault>(from: fusdStoragePath)
    fusdVault!.deposit(from: <-FUSD.test_minter.mintTokens(amount: 100.0))
    log("End -----------------------------")
  }

  execute {
  }
}
