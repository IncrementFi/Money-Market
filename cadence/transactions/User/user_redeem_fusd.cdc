import FUSD from "../../contracts/FUSD.cdc"
import FungibleToken from "../../contracts/FungibleToken.cdc"
import LendingPool from "../../contracts/LendingPool.cdc"
import ComptrollerV1 from "../../contracts/ComptrollerV1.cdc"
import Config from "../../contracts/Config.cdc"
import Interfaces from "../../contracts/Interfaces.cdc"



transaction(amountRedeem: UFix64) {
    prepare(signer: AuthAccount) {
        log("Transaction Start --------------- user_redeem_fusd")

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
        log("User redeem fusd ".concat(amountRedeem.toString()))

        // Get local user certificate
        var userCertificateCap = signer.getCapability<&{Interfaces.IdentityCertificate}>(Config.UserCertificatePrivatePath)
        if userCertificateCap.check() == false {
            if signer.borrow<&{Interfaces.IdentityCertificate}>(from: Config.UserCertificateStoragePath) == nil {
                // Create new user certificate
                let userCertificate <- ComptrollerV1.IssueUserCertificate()
                signer.save(<-userCertificate, to: Config.UserCertificateStoragePath)
                signer.link<&{Interfaces.IdentityCertificate}>(Config.UserCertificatePrivatePath, target: Config.UserCertificateStoragePath)
            }
        }
        userCertificateCap = signer.getCapability<&{Interfaces.IdentityCertificate}>(Config.UserCertificatePrivatePath)

        // redeem
        let redeemVault <- LendingPool.redeemUnderlying(userCertificateCap: userCertificateCap, numUnderlyingToRedeem: amountRedeem) ?? panic("Redeem fail.")
        fusdVault!.deposit(from: <-redeemVault)

        log("User left fusd ".concat(fusdVault!.balance.toString()))
        log("End -----------------------------")
    }

    execute {
    }
}
