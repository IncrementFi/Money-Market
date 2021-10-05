import FUSD from "../../contracts/FUSD.cdc"


transaction() {
    prepare(poolAccount: AuthAccount) {
        log("==================")
        log("创建本地fusd vault")
        poolAccount.save(<- FUSD.createEmptyVault(), to: /storage/underlyingVault)
        log("------------------")
    }
}
 