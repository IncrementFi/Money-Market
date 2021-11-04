import FUSD from "../../contracts/FUSD.cdc"
import FungibleToken from "../../contracts/FungibleToken.cdc"
import LendingPool from "../../contracts/LendingPool.cdc"

transaction(amountDeposit: UFix64) {
    prepare(signer: AuthAccount) {
        log("Transaction Start --------------- user_deposit_fusd")
        log("Test deposit fusd ".concat(amountDeposit.toString()))


        let fusdStoragePath = /storage/fusdVault
        var fusdVault = signer.borrow<&FUSD.Vault>(from: fusdStoragePath)
        if fusdVault == nil {
            log("Create new local fusd vault")
            signer.save(<-FUSD.createEmptyVault(), to: fusdStoragePath)
            signer.link<&FUSD.Vault{FungibleToken.Receiver}>(/public/fusdReceiver, target: fusdStoragePath)
            signer.link<&FUSD.Vault{FungibleToken.Balance}>(/public/fusdBalance, target: fusdStoragePath)
        }
        fusdVault = signer.borrow<&FUSD.Vault>(from: fusdStoragePath)

        assert(fusdVault!.balance >= amountDeposit, message: "No enough FUSD balance.")
        let inUnderlyingVault <-fusdVault!.withdraw(amount: amountDeposit)

        // deposit
        LendingPool.supply(supplierAddr: signer.address, inUnderlyingVault: <-inUnderlyingVault)
        
        log("User left fusd ".concat(fusdVault!.balance.toString()))
        log("End -----------------------------")
    }

    execute {
    }
}
 