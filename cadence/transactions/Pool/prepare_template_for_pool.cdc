import FlowToken from "../../contracts/FlowToken.cdc"

transaction() {
    prepare(poolAccount: AuthAccount) {
        log("Transaction Start --------------- prepare_FlowToken_vault_for_pool")
        log("Create empty FlowToken vault:")
        poolAccount.save(<- FlowToken.createEmptyVault(), to: /storage/poolUnderlyingAssetVault)
        log("End -----------------------------")
    }
}
