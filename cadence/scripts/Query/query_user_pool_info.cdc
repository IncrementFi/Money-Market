import Interfaces from "../../contracts/Interfaces.cdc"
import Config from "../../contracts/Config.cdc"



pub fun main(userAddr: Address, poolAddr: Address, comptrollerAddr: Address): {String: AnyStruct} {
    let comptrollerRef = getAccount(comptrollerAddr).getCapability<&{Interfaces.ComptrollerPublic}>(Config.ComptrollerPublicPath).borrow()
        ?? panic(
            Config.ErrorEncode (
                msg: "Invailid comptroller cap.",
                err: Config.Error.CANNOT_ACCESS_COMPTROLLER_PUBLIC_CAPABILITY
            )
        )
    let userInfo = comptrollerRef.getUserMarketInfo(userAddr: userAddr, poolAddr: poolAddr)
    
    return userInfo
}