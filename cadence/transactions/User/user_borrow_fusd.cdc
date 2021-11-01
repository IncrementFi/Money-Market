import FUSD from "../../contracts/FUSD.cdc"
import FungibleToken from "../../contracts/FungibleToken.cdc"
import LendingPool from "../../contracts/LendingPool.cdc"
import Config from "../../contracts/Config.cdc"
import Interfaces from "../../contracts/Interfaces.cdc"



transaction(amountBorrow: UFix64) {
    prepare(signer: AuthAccount) {
        log("Transaction Start --------------- user_borrow_fusd")

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
        log("User borrow fusd ".concat(amountBorrow.toString()))

        // Get local user certificate
        var userCertificateCap = signer.getCapability<&{Interfaces.IdentityCertificate}>(Config.UserCertificatePrivatePath)
        if userCertificateCap.check() == false {
            if signer.borrow<&{Interfaces.IdentityCertificate}>(from: Config.UserCertificateStoragePath) == nil {
                // Create new user certificate
                let userCertificate <- LendingPool.IssueUserCertificate()
                signer.save(<-userCertificate, to: Config.UserCertificateStoragePath)
                signer.link<&{Interfaces.IdentityCertificate}>(Config.UserCertificatePrivatePath, target: Config.UserCertificateStoragePath)
            }
        }
        userCertificateCap = signer.getCapability<&{Interfaces.IdentityCertificate}>(Config.UserCertificatePrivatePath)

        // borrow
        let borrowVault <- LendingPool.borrow(userCertificateCap: userCertificateCap, borrowAmount: amountBorrow)
        fusdVault!.deposit(from: <-borrowVault)

        log("User left fusd ".concat(fusdVault!.balance.toString()))
        log("End -----------------------------")
    }

    execute {
    }
}
