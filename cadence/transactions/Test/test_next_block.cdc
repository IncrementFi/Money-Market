import Interfaces from "../../contracts/Interfaces.cdc"
import Config from "../../contracts/Config.cdc"
transaction {

    prepare(signer: AuthAccount) {
        log("Next block ---------------")
        let poolAddrs = getAccount(0xf8d6e0586b0a20c7).getCapability<&{Interfaces.ComptrollerPublic}>(Config.ComptrollerPublicPath).borrow()!.getAllMarkets()
        for poolAddr in poolAddrs {
            getAccount(poolAddr).getCapability<&{Interfaces.PoolPublic}>(Config.PoolPublicPublicPath).borrow()!.accrueInterest()
        }
        log("End -----------------------------")
    }

    execute {
    }
}
