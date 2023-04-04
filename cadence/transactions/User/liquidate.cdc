import FlowToken from "../../contracts/tokens/FlowToken.cdc"
import FungibleToken from "../../contracts/tokens/FungibleToken.cdc"
import LendingInterfaces from "../../contracts/LendingInterfaces.cdc"
import LendingConfig from "../../contracts/LendingConfig.cdc"
import LendingComptroller from "../../contracts/LendingComptroller.cdc"
//import SwapRouter from 0xa6850776a94e6551
import SwapRouter from 0x2f8af5ed05bbde0d


// Liquidation Inform:
//
// Liquidated Address: BORROWER
// Repaied LIQUIDATEAMOUNT LIQUIDATETOKEN on your behalf
//
transaction(repayPoolAddr: Address, seizePoolAddr: Address, amountLiquidate: UFix64, borrower: Address) {
    prepare(signer: AuthAccount) {
        let poolRepayRef = getAccount(repayPoolAddr).getCapability<&{LendingInterfaces.PoolPublic}>(LendingConfig.PoolPublicPublicPath).borrow()!
        let poolSeizeRef = getAccount(seizePoolAddr).getCapability<&{LendingInterfaces.PoolPublic}>(LendingConfig.PoolPublicPublicPath).borrow()!

        let repayTokenStr = poolRepayRef.getUnderlyingTypeString()
        let seizeTokenStr = poolSeizeRef.getUnderlyingTypeString()
        let repayTokenTypeStr = getTokenTypeStr(poolRepayRef.getUnderlyingAssetType())
        let seizeTokenTypeStr = getTokenTypeStr(poolSeizeRef.getUnderlyingAssetType())
        
        var repayVaultPath = getTokenVaultPath(repayTokenStr)
        var seizeVaultPath = getTokenVaultPath(seizeTokenStr)

        var repayWallet = signer.borrow<&FungibleToken.Vault>(from: repayVaultPath)!
        var seizeWallet = signer.borrow<&FungibleToken.Vault>(from: seizeVaultPath)!

        var liquidateInAmount = repayWallet.balance
        let repayVault <- repayWallet.withdraw(amount: amountLiquidate)

        // liquidate
        let leftVault <- poolRepayRef.liquidate(
            liquidator: signer.address,
            borrower: borrower,
            poolCollateralizedToSeize: seizePoolAddr,
            repayUnderlyingVault: <-repayVault
        )
        if leftVault != nil {
            repayWallet.deposit(from: <-leftVault!)
        } else {
            destroy leftVault
        }
        liquidateInAmount = liquidateInAmount - repayWallet.balance

        // redeem all
        if (signer.borrow<&{LendingInterfaces.IdentityCertificate}>(from: LendingConfig.UserCertificateStoragePath) == nil) {
            destroy <-signer.load<@AnyResource>(from: LendingConfig.UserCertificateStoragePath)
            
            let userCertificate <- LendingComptroller.IssueUserCertificate()
            signer.save(<-userCertificate, to: LendingConfig.UserCertificateStoragePath)
            signer.link<&{LendingInterfaces.IdentityCertificate}>(LendingConfig.UserCertificatePrivatePath, target: LendingConfig.UserCertificateStoragePath)
        }
        if (signer.getCapability<&{LendingInterfaces.IdentityCertificate}>(LendingConfig.UserCertificatePrivatePath).check()==false) {
            signer.link<&{LendingInterfaces.IdentityCertificate}>(LendingConfig.UserCertificatePrivatePath, target: LendingConfig.UserCertificateStoragePath)
        }
        let userCertificateCap = signer.getCapability<&{LendingInterfaces.IdentityCertificate}>(LendingConfig.UserCertificatePrivatePath)
        let redeemedVault <- poolSeizeRef.redeemUnderlying(userCertificateCap: userCertificateCap, numUnderlyingToRedeem: UFix64.max)
        
        // swap or withdraw
        var swapPath: [String] = []
        if seizeTokenStr == "FiatToken" && repayTokenStr == "FlowToken" { swapPath = [seizeTokenTypeStr, repayTokenTypeStr] }
        if seizeTokenStr == "FlowToken" && repayTokenStr == "FiatToken" { swapPath = [seizeTokenTypeStr, repayTokenTypeStr] }
        if seizeTokenStr == "stFlowToken" && repayTokenStr == "FiatToken" { swapPath = [seizeTokenTypeStr, "A.1654653399040a61.FlowToken", repayTokenTypeStr] }
        if seizeTokenStr == "stFlowToken" && repayTokenStr == "FlowToken" { swapPath = [seizeTokenTypeStr, repayTokenTypeStr] }
        if seizeTokenStr == "FiatToken" && repayTokenStr == "stFlowToken" { swapPath = [seizeTokenTypeStr, "A.1654653399040a61.FlowToken", repayTokenTypeStr] }
        if seizeTokenStr == "FlowToken" && repayTokenStr == "stFlowToken" { swapPath = [seizeTokenTypeStr, repayTokenTypeStr] }
        if swapPath.length > 0 {
            let vaultOut <- SwapRouter.swapWithPath(vaultIn: <- redeemedVault, tokenKeyPath: swapPath, exactAmounts: nil)
            assert(vaultOut.balance > liquidateInAmount, message: "liquidate with no profit")
            repayWallet.deposit(from: <-vaultOut)
        } else {
            // no swap
            seizeWallet.deposit(from: <-redeemedVault)
        }        
        
        // inform
        let informVault <- signer.borrow<&FungibleToken.Vault>(from: /storage/flowTokenVault)!.withdraw(amount: 0.00000001)
        let flowTokenReceiverRef = getAccount(borrower).getCapability(/public/flowTokenReceiver).borrow<&{FungibleToken.Receiver}>()!
        flowTokenReceiverRef.deposit(from: <-informVault)
    }
}

pub fun getTokenVaultPath(_ tokenStr: String): StoragePath {
    var vaultPath = /storage/null
    switch tokenStr {
        case "FlowToken": vaultPath = /storage/flowTokenVault
        case "stFlowToken": vaultPath = /storage/stFlowTokenVault
        case "FiatToken": vaultPath = /storage/USDCVault
        case "FUSD": vaultPath = /storage/fusdVault
        case "BloctoToken": vaultPath = /storage/bloctoTokenVault
    }

    return vaultPath
}
pub fun getTokenTypeStr(_ vaultTypeStr: String): String {
    return vaultTypeStr.slice(from: 0, upTo: vaultTypeStr.length - 6)
}