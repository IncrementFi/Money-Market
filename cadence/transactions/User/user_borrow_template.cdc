import FlowToken from "../../contracts/FlowToken.cdc"
import FungibleToken from "../../contracts/FungibleToken.cdc"
import LendingPool from "../../contracts/LendingPool.cdc"
import ComptrollerV1 from "../../contracts/ComptrollerV1.cdc"
import Config from "../../contracts/Config.cdc"
import Interfaces from "../../contracts/Interfaces.cdc"


transaction(amountBorrow: UFix64) {
    let flowTokenVault: &FlowToken.Vault
    let userCertificateCap: Capability<&{Interfaces.IdentityCertificate}>

    prepare(signer: AuthAccount) {
        log("Transaction Start --------------- user_borrow_flow")

        let flowTokenStoragePath = /storage/flowTokenVault
        if (signer.borrow<&FlowToken.Vault>(from: flowTokenStoragePath) == nil) {
            log("Create new local flowToken vault")
            signer.save(<-FlowToken.createEmptyVault(), to: flowTokenStoragePath)
            signer.link<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver, target: flowTokenStoragePath)
            signer.link<&FlowToken.Vault{FungibleToken.Balance}>(/public/flowTokenBalance, target: flowTokenStoragePath)
        }
        self.flowTokenVault = signer.borrow<&FlowToken.Vault>(from: flowTokenStoragePath) ?? panic("cannot borrow reference to FlowToken Vault")
        log("User left flow ".concat(self.flowTokenVault.balance.toString()))
        log("User borrow flow ".concat(amountBorrow.toString()))

        // Get protocol-issued user certificate
        if (signer.borrow<&{Interfaces.IdentityCertificate}>(from: Config.UserCertificateStoragePath) == nil) {
            let userCertificate <- ComptrollerV1.IssueUserCertificate()
            signer.save(<-userCertificate, to: Config.UserCertificateStoragePath)
            signer.link<&{Interfaces.IdentityCertificate}>(Config.UserCertificatePrivatePath, target: Config.UserCertificateStoragePath)
        }
        self.userCertificateCap = signer.getCapability<&{Interfaces.IdentityCertificate}>(Config.UserCertificatePrivatePath)
    }

    execute {
        let borrowVault <- LendingPool.borrow(userCertificateCap: self.userCertificateCap, borrowAmount: amountBorrow)
        self.flowTokenVault.deposit(from: <-borrowVault)

        log("User left flow ".concat(self.flowTokenVault.balance.toString()))
        log("End -----------------------------")
    }
}
