import LendingInterfaces from "../../contracts/LendingInterfaces.cdc"
import LendingConfig from "../../contracts/LendingConfig.cdc"
transaction() {

    prepare(signer: AuthAccount) {
        log("Next block --------------- pre block id: ".concat(getCurrentBlock().height.toString()))
        let poolAddrs = signer.getCapability<&{LendingInterfaces.ComptrollerPublic}>(LendingConfig.ComptrollerPublicPath).borrow()!.getAllMarkets()
        for poolAddr in poolAddrs {
            getAccount(poolAddr).getCapability<&{LendingInterfaces.PoolPublic}>(LendingConfig.PoolPublicPublicPath).borrow()!.accrueInterest()
        }
        log("End ---------------------- aft block id: ".concat(getCurrentBlock().height.toString()))
    }

    execute {
    }
}