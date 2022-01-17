import FlowToken from "../../contracts/FlowToken.cdc"
import FungibleToken from "../../contracts/FungibleToken.cdc"
import LendingPool from "../../contracts/LendingPool.cdc"
import ComptrollerV1 from "../../contracts/ComptrollerV1.cdc"
import LendingConfig from "../../contracts/LendingConfig.cdc"
import LendingInterfaces from "../../contracts/LendingInterfaces.cdc"


transaction(amountBorrow: UFix64) {
    let flowTokenVault: &FlowToken.Vault
    let userCertificateCap: Capability<&{LendingInterfaces.IdentityCertificate}>

    prepare(signer: AuthAccount) {
        log("Transaction Start --------------- user_borrow_flowToken")

        let flowTokenStoragePath = /storage/flowTokenVault
        if (signer.borrow<&FlowToken.Vault>(from: flowTokenStoragePath) == nil) {
            log("Create new local flowToken vault")
            signer.save(<-FlowToken.createEmptyVault(), to: flowTokenStoragePath)
            signer.link<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver, target: flowTokenStoragePath)
            signer.link<&FlowToken.Vault{FungibleToken.Balance}>(/public/flowTokenBalance, target: flowTokenStoragePath)
        }
        self.flowTokenVault = signer.borrow<&FlowToken.Vault>(from: flowTokenStoragePath) ?? panic("cannot borrow reference to FlowToken Vault")
        log("User left flowToken ".concat(self.flowTokenVault.balance.toString()))
        log("User borrow flowToken ".concat(amountBorrow.toString()))

        // Get protocol-issued user certificate
        if (signer.borrow<&{LendingInterfaces.IdentityCertificate}>(from: LendingConfig.UserCertificateStoragePath) == nil) {
            let userCertificate <- ComptrollerV1.IssueUserCertificate()
            signer.save(<-userCertificate, to: LendingConfig.UserCertificateStoragePath)
            signer.link<&{LendingInterfaces.IdentityCertificate}>(LendingConfig.UserCertificatePrivatePath, target: LendingConfig.UserCertificateStoragePath)
        }
        self.userCertificateCap = signer.getCapability<&{LendingInterfaces.IdentityCertificate}>(LendingConfig.UserCertificatePrivatePath)
    }

    execute {
        let borrowVault <- LendingPool.borrow(userCertificateCap: self.userCertificateCap, borrowAmount: amountBorrow)
        self.flowTokenVault.deposit(from: <-borrowVault)

        log("User left flowToken ".concat(self.flowTokenVault.balance.toString()))
        log("End -----------------------------")
    }
}
