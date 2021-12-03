import Interfaces from "../../contracts/Interfaces.cdc"
import Config from "../../contracts/Config.cdc"

pub fun main(userAddr: Address, comptrollerAddr: Address): [Address] {
    let comptrollerRef = getAccount(comptrollerAddr).getCapability<&{Interfaces.ComptrollerPublic}>(Config.ComptrollerPublicPath).borrow()
        ?? panic(
            Config.ErrorEncode (
                msg: "Invailid comptroller cap.",
                err: Config.Error.CANNOT_ACCESS_COMPTROLLER_PUBLIC_CAPABILITY
            )    
        )
    let poolAddrs = comptrollerRef.getUserMarkets(userAddr: userAddr)
    log(poolAddrs)
    return poolAddrs
}