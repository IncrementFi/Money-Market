import LendingPool from "../../contracts/LendingPool.cdc"

transaction(interestRateModelAddr: Address, comptrollerAddr: Address) {
    prepare(poolAccount: AuthAccount) {
        log("Transaction Start --------------- init_flow_pool")
        
        log("Init pool of fusd:")
        let PoolAdminRef = poolAccount.borrow<&LendingPool.PoolAdmin>(from: LendingPool.PoolAdminStoragePath) ?? panic("Lost pool admin of fusd.")
        PoolAdminRef.initializePool(
            reserveFactor: 0.01,
            poolSeizeShare: 0.028,
            interestRateModelAddress: interestRateModelAddr
        )

        log("Set comptroller:")
        PoolAdminRef.setComptroller(newComptrollerAddress: comptrollerAddr)

        log("End -----------------------------")
    }
}