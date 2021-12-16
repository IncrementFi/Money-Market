import FUSD from "../../contracts/FUSD.cdc"
import FungibleToken from "../../contracts/FungibleToken.cdc"

transaction(mintAmount: UFix64) {

    prepare(signer: AuthAccount) {
        log("Transaction Start ---------------")
        log("user add fusd".concat(mintAmount.toString()))
        let fusdStoragePath = /storage/fusdVault
        var fusdVault = signer.borrow<&FUSD.Vault>(from: fusdStoragePath)
        if fusdVault == nil {
            signer.save(<-FUSD.createEmptyVault(), to: fusdStoragePath)
            signer.link<&FUSD.Vault{FungibleToken.Receiver}>(/public/fusdReceiver, target: fusdStoragePath)
            signer.link<&FUSD.Vault{FungibleToken.Balance}>(/public/fusdBalance, target: fusdStoragePath)
        }
        fusdVault = signer.borrow<&FUSD.Vault>(from: fusdStoragePath)
        fusdVault!.deposit(from: <-FUSD.test_minter.mintTokens(amount: mintAmount))
        log("End -----------------------------")
    }
}
