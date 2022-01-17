import FlowToken from "../../contracts/tokens/FlowToken.cdc"
import FungibleToken from "../../contracts/tokens/FungibleToken.cdc"

transaction() {
    prepare(poolAccount: AuthAccount) {
        let preUnderlyingVault <- poolAccount.load<@FungibleToken.Vault>(from: /storage/poolUnderlyingAssetVault)
        if preUnderlyingVault != nil {
            let flowTokenStoragePath = /storage/flowTokenVault
            if (poolAccount.borrow<&FlowToken.Vault>(from: flowTokenStoragePath) == nil) {
                poolAccount.save(<-FlowToken.createEmptyVault(), to: flowTokenStoragePath)
                poolAccount.link<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver, target: flowTokenStoragePath)
                poolAccount.link<&FlowToken.Vault{FungibleToken.Balance}>(/public/flowTokenBalance, target: flowTokenStoragePath)
            }
            let receiverRef =  poolAccount.getCapability(/public/flowTokenReceiver).borrow<&{FungibleToken.Receiver}>()
                ?? panic("There is no local FlowToken vault in public/flowTokenReceiver, may lost the pre pool's vault in poolUnderlyingAssetVault")
            receiverRef.deposit(from: <-preUnderlyingVault!)
        } else {
            destroy preUnderlyingVault
        }
        poolAccount.save(<- FlowToken.createEmptyVault(), to: /storage/poolUnderlyingAssetVault)
    }
}
