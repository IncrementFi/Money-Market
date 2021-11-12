import FlowToken from "../../contracts/FlowToken.cdc"

transaction() {
    prepare(poolAccount: AuthAccount) {
        log("Transaction Start --------------- prepare_flow_vault_for_pool")
        log("Create empty flow vault:")
        poolAccount.save(<- FlowToken.createEmptyVault(), to: /storage/poolUnderlyingAssetVault)
        log("End -----------------------------")
    }
}
