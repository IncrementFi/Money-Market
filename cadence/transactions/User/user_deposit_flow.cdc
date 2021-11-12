import FlowToken from "../../contracts/FlowToken.cdc"
import FungibleToken from "../../contracts/FungibleToken.cdc"
import LendingPool from "../../contracts/LendingPool.cdc"

transaction(amountDeposit: UFix64) {
    let flowTokenVault: &FlowToken.Vault
    let supplierAddress: Address

    prepare(signer: AuthAccount) {
        log("Transaction Start --------------- user_deposit_flow")
        log("Test deposit flow ".concat(amountDeposit.toString()))

        let flowTokenStoragePath = /storage/flowTokenVault
        if (signer.borrow<&FlowToken.Vault>(from: flowTokenStoragePath) == nil) {
            log("Create new local flowToken vault")
            signer.save(<-FlowToken.createEmptyVault(), to: flowTokenStoragePath)
            signer.link<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver, target: flowTokenStoragePath)
            signer.link<&FlowToken.Vault{FungibleToken.Balance}>(/public/flowTokenBalance, target: flowTokenStoragePath)
        }
        self.flowTokenVault = signer.borrow<&FlowToken.Vault>(from: flowTokenStoragePath) ?? panic("cannot borrow reference to FlowToken Vault")
        self.supplierAddress = signer.address
    }

    execute {
        let inUnderlyingVault <- self.flowTokenVault.withdraw(amount: amountDeposit)
        LendingPool.supply(supplierAddr: self.supplierAddress, inUnderlyingVault: <-inUnderlyingVault)

        log("User left flow ".concat(self.flowTokenVault.balance.toString()))
        log("End -----------------------------")
    }
}
 