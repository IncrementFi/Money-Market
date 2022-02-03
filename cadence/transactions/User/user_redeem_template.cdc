import FlowToken from "../../contracts/tokens/FlowToken.cdc"
import FungibleToken from "../../contracts/tokens/FungibleToken.cdc"
import LendingPool from "../../contracts/LendingPool.cdc"
import LendingComptroller from "../../contracts/LendingComptroller.cdc"
import LendingConfig from "../../contracts/LendingConfig.cdc"
import LendingInterfaces from "../../contracts/LendingInterfaces.cdc"

transaction(amountUnderlyingToRedeem: UFix64) {
    let flowTokenVault: &FlowToken.Vault
    let userCertificateCap: Capability<&{LendingInterfaces.IdentityCertificate}>

    prepare(signer: AuthAccount) {
        log("Transaction Start --------------- user_redeem_flowToken")

        let flowTokenStoragePath = /storage/flowTokenVault
        if (signer.borrow<&FlowToken.Vault>(from: flowTokenStoragePath) == nil) {
            log("Create new local flowToken vault")
            signer.save(<-FlowToken.createEmptyVault(), to: flowTokenStoragePath)
            signer.link<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver, target: flowTokenStoragePath)
            signer.link<&FlowToken.Vault{FungibleToken.Balance}>(/public/flowTokenBalance, target: flowTokenStoragePath)
        }
        self.flowTokenVault = signer.borrow<&FlowToken.Vault>(from: flowTokenStoragePath) ?? panic("cannot borrow reference to FlowToken Vault")
        log("User left flowToken ".concat(self.flowTokenVault.balance.toString()))
        log("User redeem flowToken ".concat(amountUnderlyingToRedeem.toString()))

        // Get protocol-issued user certificate
        if (signer.borrow<&{LendingInterfaces.IdentityCertificate}>(from: LendingConfig.UserCertificateStoragePath) == nil) {
            destroy <-signer.load<@AnyResource>(from: LendingConfig.UserCertificateStoragePath)
            
            let userCertificate <- LendingComptroller.IssueUserCertificate()
            signer.save(<-userCertificate, to: LendingConfig.UserCertificateStoragePath)
            signer.link<&{LendingInterfaces.IdentityCertificate}>(LendingConfig.UserCertificatePrivatePath, target: LendingConfig.UserCertificateStoragePath)
        }
        if (signer.getCapability<&{LendingInterfaces.IdentityCertificate}>(LendingConfig.UserCertificatePrivatePath).check()==false) {
            signer.link<&{LendingInterfaces.IdentityCertificate}>(LendingConfig.UserCertificatePrivatePath, target: LendingConfig.UserCertificateStoragePath)
        }
        self.userCertificateCap = signer.getCapability<&{LendingInterfaces.IdentityCertificate}>(LendingConfig.UserCertificatePrivatePath)
    }

    execute {
        let redeemedVault <- LendingPool.redeemUnderlying(userCertificateCap: self.userCertificateCap, numUnderlyingToRedeem: amountUnderlyingToRedeem)
        self.flowTokenVault.deposit(from: <-redeemedVault)

        log("User left flowToken ".concat(self.flowTokenVault.balance.toString()))
        log("End -----------------------------")
    }
}
