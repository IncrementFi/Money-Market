import FUSD from "../../contracts/FUSD.cdc"


transaction() {
    prepare(poolAccount: AuthAccount) {
        log("Transaction Start --------------- create_fusdvault_of_pool")
        log("Create local fusd vault:")
        poolAccount.save(<- FUSD.createEmptyVault(), to: /storage/underlyingVault)
        log("End -----------------------------")
    }
}
