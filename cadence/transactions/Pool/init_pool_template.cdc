import LendingPool from "../../contracts/LendingPool.cdc"

transaction(interestRateModelAddr: Address, comptrollerAddr: Address, reserveFactor: UFix64, poolSeizeShare: UFix64) {

    let PoolAdminRef: &LendingPool.PoolAdmin

    prepare(poolAccount: AuthAccount) {
        self.PoolAdminRef = poolAccount.borrow<&LendingPool.PoolAdmin>(from: LendingPool.PoolAdminStoragePath) ?? panic("Lost pool admin.")
    }

    execute {
        self.PoolAdminRef.initializePool(
            reserveFactor: reserveFactor,
            poolSeizeShare: poolSeizeShare,
            interestRateModelAddress: interestRateModelAddr
        )

        self.PoolAdminRef.setComptroller(newComptrollerAddress: comptrollerAddr)
    }
}