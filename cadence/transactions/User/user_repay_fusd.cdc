import FUSD from "../../contracts/FUSD.cdc"
import FungibleToken from "../../contracts/FungibleToken.cdc"
import LendingPool from "../../contracts/LendingPool.cdc"

transaction(amountRepay: UFix64) {
    prepare(signer: AuthAccount) {
        log("Transaction Start --------------- user_deposit_fusd")
        
        let fusdStoragePath = /storage/fusdVault
        var fusdVault = signer.borrow<&FUSD.Vault>(from: fusdStoragePath)
        if fusdVault == nil {
            log("Create new local fusd vault")
            signer.save(<-FUSD.createEmptyVault(), to: fusdStoragePath)
            signer.link<&FUSD.Vault{FungibleToken.Receiver}>(/public/fusdReceiver, target: fusdStoragePath)
            signer.link<&FUSD.Vault{FungibleToken.Balance}>(/public/fusdBalance, target: fusdStoragePath)
        }
        fusdVault = signer.borrow<&FUSD.Vault>(from: fusdStoragePath)
        log("User left fusd ".concat(fusdVault!.balance.toString()))
        log("Test repay fusd ".concat(amountRepay.toString()))

        assert(fusdVault!.balance >= amountRepay, message: "No enough FUSD balance.")
        let inUnderlyingVault <-fusdVault!.withdraw(amount: amountRepay)

        // deposit
        let leftVault <- LendingPool.repayBorrow(borrower: signer.address, repayUnderlyingVault: <-inUnderlyingVault)
        if leftVault != nil {
            fusdVault!.deposit(from: <-leftVault!)
        } else {
            destroy leftVault
        }
        
        log("User left fusd ".concat(fusdVault!.balance.toString()))
        log("End -----------------------------")
    }

    execute {
    }
}
