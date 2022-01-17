import LendingPool from "../../contracts/LendingPool.cdc"

transaction(interestRateModelAddr: Address, comptrollerAddr: Address, reserveFactor: UFix64, poolSeizeShare: UFix64) {
    prepare(poolAccount: AuthAccount) {
        let PoolAdminRef = poolAccount.borrow<&LendingPool.PoolAdmin>(from: LendingPool.PoolAdminStoragePath) ?? panic("Lost pool admin.")
        PoolAdminRef.initializePool(
            reserveFactor: reserveFactor,
            poolSeizeShare: poolSeizeShare,
            interestRateModelAddress: interestRateModelAddr
        )

        PoolAdminRef.setComptroller(newComptrollerAddress: comptrollerAddr)
    }
}