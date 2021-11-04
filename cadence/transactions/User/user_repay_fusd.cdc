import FUSD from "../../contracts/FUSD.cdc"
import FungibleToken from "../../contracts/FungibleToken.cdc"
import LendingPool from "../../contracts/LendingPool.cdc"
import Interfaces from "../../contracts/Interfaces.cdc"
import Config from "../../contracts/Config.cdc"

transaction(amount: UFix64) {
    prepare(signer: AuthAccount) {
        log("Transaction Start --------------- user_repay_fusd")
        
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

        var amountRepay = amount
        if amountRepay == UFix64.max {
            let poolPublicRef = getAccount(Config.FUSDPoolAddr).getCapability<&{Interfaces.PoolPublic}>(Config.PoolPublicPublicPath).borrow()!
            amountRepay = poolPublicRef.getAccountBorrowBalance(account: signer.address)
        }
        log("Test repay fusd ".concat(amountRepay.toString()))
        assert(fusdVault!.balance >= amountRepay, message: "No enough FUSD balance.")
        let inUnderlyingVault <-fusdVault!.withdraw(amount: amountRepay)

        // repay
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
