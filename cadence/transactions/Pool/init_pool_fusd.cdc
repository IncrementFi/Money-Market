import LendingPool from "../../contracts/LendingPool.cdc"
import Config from "../../contracts/Config.cdc"

transaction() {
    prepare(poolAccount: AuthAccount) {
        log("Transaction Start --------------- init_pool_fusd")
        
        log("Init pool of fusd:")
        let PoolAdminRef = poolAccount.borrow<&LendingPool.PoolAdmin>(from: LendingPool.PoolAdminStoragePath) ?? panic("Lost pool admin of fusd.")
        PoolAdminRef.initializePool(
            reserveFactor: 0.01,
            poolSeizeShare: 0.028,
            interestRateModelAddress: Config.InterestModelAddr
        )

        log("Set comptroller:")
        PoolAdminRef.setComptroller(newComptrollerAddress: Config.ComptrollerAddr)

        log("End -----------------------------")
    }
}