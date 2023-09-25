import LendingPool from "../../contracts/LendingPool.cdc"

transaction(newInterestRateModelAddr: Address) {
    prepare(poolAccount: AuthAccount) {
        let poolAdminRef = poolAccount.borrow<&LendingPool.PoolAdmin>(from: LendingPool.PoolAdminStoragePath)
            ?? panic("cannot borrow reference to pool admin")
        poolAdminRef.setInterestRateModel(newInterestRateModelAddress: newInterestRateModelAddr)
    }
}