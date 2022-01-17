import FlowToken from "../../contracts/tokens/FlowToken.cdc"
import FungibleToken from "../../contracts/tokens/FungibleToken.cdc"
import LendingPool from "../../contracts/LendingPool.cdc"

transaction(amountLiquidate: UFix64, borrower: Address, seizePoolAddr: Address) {
    let flowTokenVault: &FlowToken.Vault
    let liquidatorAddr: Address

    prepare(signer: AuthAccount) {
        log("Transaction Start --------------- liquidate_flowToken_pool")
        log("Test liquidate FlowToken ".concat(amountLiquidate.toString()))

        let flowTokenStoragePath = /storage/flowTokenVault
        
        self.flowTokenVault  = signer.borrow<&FlowToken.Vault>(from: flowTokenStoragePath) ?? panic("cannot borrow reference to FlowToken Vault")
        log("liquidator's vault ".concat(self.flowTokenVault.balance.toString()))
        self.liquidatorAddr = signer.address
    }

    execute {
        let inUnderlyingVault <- self.flowTokenVault.withdraw(amount: amountLiquidate)
        let leftVault <- LendingPool.liquidate(
            liquidator: self.liquidatorAddr,
            borrower: borrower,
            poolCollateralizedToSeize: seizePoolAddr,
            repayUnderlyingVault: <-inUnderlyingVault
        )
        if leftVault != nil {
            self.flowTokenVault.deposit(from: <-leftVault!)
        } else {
            destroy leftVault
        }

        log("End -----------------------------")
    }
}
 