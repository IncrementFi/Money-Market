import FlowToken from "../../contracts/FlowToken.cdc"
import FungibleToken from "../../contracts/FungibleToken.cdc"
import LendingPool from "../../contracts/LendingPool.cdc"
import Interfaces from "../../contracts/Interfaces.cdc"
import Config from "../../contracts/Config.cdc"

transaction() {
    let flowTokenVault: &FlowToken.Vault
    let borrowerAddress: Address

    prepare(signer: AuthAccount) {
        log("Transaction Start --------------- user_repay_flowToken")
        
        let flowTokenStoragePath = /storage/flowTokenVault
        if (signer.borrow<&FlowToken.Vault>(from: flowTokenStoragePath) == nil) {
            log("Create new local flowToken vault")
            signer.save(<-FlowToken.createEmptyVault(), to: flowTokenStoragePath)
            signer.link<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver, target: flowTokenStoragePath)
            signer.link<&FlowToken.Vault{FungibleToken.Balance}>(/public/flowTokenBalance, target: flowTokenStoragePath)
        }
        self.flowTokenVault = signer.borrow<&FlowToken.Vault>(from: flowTokenStoragePath) ?? panic("cannot borrow reference to FlowToken Vault")
        self.borrowerAddress = signer.address
        log("User left flowToken ".concat(self.flowTokenVault.balance.toString()))
    }

    execute {
        // accrueInterest() to update with latest pool states used to calculate borrowBalance
        LendingPool.accrueInterest()
        let totalRepayScaled = LendingPool.borrowBalanceSnapshotScaled(borrowerAddress: self.borrowerAddress)
        var amountRepay = Config.ScaledUInt256ToUFix64(totalRepayScaled) + 1.0/Config.ufixScale

        let inUnderlyingVault <- self.flowTokenVault.withdraw(amount: amountRepay)
        let leftVault <- LendingPool.repayBorrow(borrower: self.borrowerAddress, repayUnderlyingVault: <-inUnderlyingVault)
        if leftVault != nil {
            self.flowTokenVault.deposit(from: <-leftVault!)
        } else {
            destroy leftVault
        }
        
        log("User left flowToken ".concat(self.flowTokenVault.balance.toString()))
        log("End -----------------------------")
    }
}
