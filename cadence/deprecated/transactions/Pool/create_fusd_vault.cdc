import FUSD from "../../contracts/FUSD.cdc"


transaction() {
    prepare(poolAccount: AuthAccount) {
        log("Transaction Start ---------------")
        log("create local fusd vault:")
        poolAccount.save(<- FUSD.createEmptyVault(), to: /storage/underlyingVault)
        log("End -----------------------------")
    }
}
