import FlowToken from "../../contracts/tokens/FlowToken.cdc"
import FungibleToken from "../../contracts/tokens/FungibleToken.cdc"
import LendingPool from "../../contracts/LendingPool.cdc"

transaction(amountDeposit: UFix64) {
    let flowTokenVault: &FlowToken.Vault
    let supplierAddress: Address

    prepare(signer: AuthAccount) {
        log("Transaction Start --------------- user_deposit_flowToken")
        log("Test deposit FlowToken ".concat(amountDeposit.toString()))

        let flowTokenStoragePath = /storage/flowTokenVault
        if (signer.borrow<&FlowToken.Vault>(from: flowTokenStoragePath) == nil) {
            log("Create new local flowToken vault")
            signer.save(<-FlowToken.createEmptyVault(), to: flowTokenStoragePath)
            signer.link<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver, target: flowTokenStoragePath)
            signer.link<&FlowToken.Vault{FungibleToken.Balance}>(/public/flowTokenBalance, target: flowTokenStoragePath)
        }
        self.flowTokenVault = signer.borrow<&FlowToken.Vault>(from: flowTokenStoragePath) ?? panic("cannot borrow reference to FlowToken Vault")
        log("User vault :".concat(self.flowTokenVault.balance.toString()))
        self.supplierAddress = signer.address
    }

    execute {
        let inUnderlyingVault <- self.flowTokenVault.withdraw(amount: amountDeposit)
        LendingPool.supply(supplierAddr: self.supplierAddress, inUnderlyingVault: <-inUnderlyingVault)

        log("User left flowToken ".concat(self.flowTokenVault.balance.toString()))
        log("End -----------------------------")
    }
}
 