import FlowToken from "../../contracts/tokens/FlowToken.cdc"
import FungibleToken from "../../contracts/tokens/FungibleToken.cdc"
import LendingPool from "../../contracts/LendingPool.cdc"
import LendingInterfaces from "../../contracts/LendingInterfaces.cdc"
import LendingConfig from "../../contracts/LendingConfig.cdc"

transaction(amount: UFix64) {
    let flowTokenVault: &FlowToken.Vault
    let borrowerAddress: Address

    prepare(signer: AuthAccount) {
        let flowTokenStoragePath = /storage/flowTokenVault
        if (signer.borrow<&FlowToken.Vault>(from: flowTokenStoragePath) == nil) {
            signer.save(<-FlowToken.createEmptyVault(), to: flowTokenStoragePath)
            signer.link<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver, target: flowTokenStoragePath)
            signer.link<&FlowToken.Vault{FungibleToken.Balance}>(/public/flowTokenBalance, target: flowTokenStoragePath)
        }
        self.flowTokenVault = signer.borrow<&FlowToken.Vault>(from: flowTokenStoragePath) ?? panic("cannot borrow reference to FlowToken Vault")
        self.borrowerAddress = signer.address
    }

    execute {
        var amountRepay = amount
        if amountRepay == UFix64.max {
            // accrueInterest() to update with latest pool states used to calculate borrowBalance
            LendingPool.accrueInterest()
            let totalRepayScaled = LendingPool.borrowBalanceSnapshotScaled(borrowerAddress: self.borrowerAddress)
            amountRepay = LendingConfig.ScaledUInt256ToUFix64(totalRepayScaled) + 1.0/LendingConfig.ufixScale
        }

        let inUnderlyingVault <- self.flowTokenVault.withdraw(amount: amountRepay)
        let leftVault <- LendingPool.repayBorrow(borrower: self.borrowerAddress, repayUnderlyingVault: <-inUnderlyingVault)
        if leftVault != nil {
            self.flowTokenVault.deposit(from: <-leftVault!)
        } else {
            destroy leftVault
        }
    }
}
