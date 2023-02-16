import FlowToken from "../../contracts/tokens/FlowToken.cdc"
import FungibleToken from "../../contracts/tokens/FungibleToken.cdc"
import LendingPool from "../../contracts/LendingPool.cdc"

// Liquidation Inform:
//
// Liquidated Address: BORROWER
// Repaied LIQUIDATEAMOUNT LIQUIDATETOKEN on your behalf
//
transaction(amountLiquidate: UFix64, borrower: Address, seizePoolAddr: Address) {
    let flowTokenVault: &FlowToken.Vault
    let liquidatorAddr: Address
    let informVault: @FungibleToken.Vault

    prepare(signer: AuthAccount) {
        let flowTokenStoragePath = /storage/flowTokenVault
        self.flowTokenVault  = signer.borrow<&FlowToken.Vault>(from: flowTokenStoragePath) ?? panic("cannot borrow reference to FlowToken Vault")
        self.liquidatorAddr = signer.address

        self.informVault <- signer.borrow<&FungibleToken.Vault>(from: /storage/flowTokenVault)!.withdraw(amount: 0.00000001)
    }

    execute {
        let inUnderlyingVault <- self.flowTokenVault.withdraw(amount: amountLiquidate)
        // liquidate
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

        // inform
        let flowTokenReceiverRef = getAccount(borrower).getCapability(/public/flowTokenReceiver).borrow<&{FungibleToken.Receiver}>()!
        flowTokenReceiverRef.deposit(from: <-self.informVault)
    }
}
 
