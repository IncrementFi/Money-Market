import LendingInterfaces from "../../contracts/LendingInterfaces.cdc"
import Config from "../../contracts/Config.cdc"
import Error from "../../contracts/Error.cdc"


pub fun main(userAddr: Address, poolAddr: Address, comptrollerAddr: Address): {String: AnyStruct} {
    let comptrollerRef = getAccount(comptrollerAddr).getCapability<&{LendingInterfaces.ComptrollerPublic}>(Config.ComptrollerPublicPath).borrow()
        ?? panic(
            Error.ErrorEncode (
                msg: "Invailid comptroller cap.",
                err: Error.ErrorCode.CANNOT_ACCESS_COMPTROLLER_PUBLIC_CAPABILITY
            )
        )
    let userInfo = comptrollerRef.getUserMarketInfo(userAddr: userAddr, poolAddr: poolAddr)
    
    return userInfo
}