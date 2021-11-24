import LendingPool from "../../contracts/LendingPool.cdc"

transaction(interestRateModelAddr: Address, comptrollerAddr: Address, reserveFactor: UFix64, poolSeizeShare: UFix64) {
    prepare(poolAccount: AuthAccount) {
        log("Transaction Start --------------- init_flow_pool")
        
        log("Init pool of fusd:")
        let PoolAdminRef = poolAccount.borrow<&LendingPool.PoolAdmin>(from: LendingPool.PoolAdminStoragePath) ?? panic("Lost pool admin.")
        PoolAdminRef.initializePool(
            reserveFactor: reserveFactor,
            poolSeizeShare: poolSeizeShare,
            interestRateModelAddress: interestRateModelAddr
        )

        log("Set comptroller:")
        PoolAdminRef.setComptroller(newComptrollerAddress: comptrollerAddr)

        log("End -----------------------------")
    }
}