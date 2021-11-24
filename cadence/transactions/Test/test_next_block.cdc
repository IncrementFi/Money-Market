import Interfaces from "../../contracts/Interfaces.cdc"
import Config from "../../contracts/Config.cdc"
transaction() {

    prepare(signer: AuthAccount) {
        log("Next block --------------- pre block id: ".concat(getCurrentBlock().height.toString()))
        let poolAddrs = signer.getCapability<&{Interfaces.ComptrollerPublic}>(Config.ComptrollerPublicPath).borrow()!.getAllMarkets()
        for poolAddr in poolAddrs {
            getAccount(poolAddr).getCapability<&{Interfaces.PoolPublic}>(Config.PoolPublicPublicPath).borrow()!.accrueInterest()
        }
        log("End ---------------------- aft block id: ".concat(getCurrentBlock().height.toString()))
    }

    execute {
    }
}