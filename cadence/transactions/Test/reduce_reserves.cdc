import LendingPool_FUSD from "../../contracts/autogen/LendingPool_FUSD.cdc"

transaction() {
    prepare(poolAccount: AuthAccount) {
        log("Transaction Start --------------- init_flow_pool")
        
        log("Init pool of fusd:")
        LendingPool_FUSD.accrueInterest()
        let PoolAdminRef = poolAccount.borrow<&LendingPool_FUSD.PoolAdmin>(from: LendingPool_FUSD.PoolAdminStoragePath) ?? panic("Lost pool admin.")
        let v <- PoolAdminRef.reduceReserves(reduceAmount: 0.000001)
        destroy v



        log("End -----------------------------")
    }
}