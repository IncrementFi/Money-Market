import FungibleToken from "../../contracts/FungibleToken.cdc"
import FlowToken from "../../contracts/FlowToken.cdc"


transaction(to: Address) {

  prepare(signer: AuthAccount) {
    log("Transaction Start ---------------")

    log("account deposit 100.0 FlowToken")
    // Get a reference to the signer's stored vault
    let vaultRef = signer.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
      ?? panic("Could not borrow reference to the owner's Vault!")

    // Withdraw tokens from the signer's stored vault
    let sentVault <- vaultRef.withdraw(amount: 100.0)

    // Get a reference to the recipient's Receiver
    let receiverRef =  getAccount(to)
        .getCapability(/public/flowTokenReceiver)
        .borrow<&{FungibleToken.Receiver}>()
        ?? panic("Could not borrow receiver reference to the recipient's Vault")

    // Deposit the withdrawn tokens in the recipient's receiver
    receiverRef.deposit(from: <-sentVault)
    
    log("End -----------------------------")
  }

  execute {
  }
}
