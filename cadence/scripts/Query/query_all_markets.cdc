import LendingInterfaces from "../../contracts/LendingInterfaces.cdc"
import Config from "../../contracts/Config.cdc"
import Error from "../../contracts/Error.cdc"

pub fun main(comptrollerAddr: Address): [Address] {
    let comptrollerRef = getAccount(comptrollerAddr).getCapability<&{LendingInterfaces.ComptrollerPublic}>(Config.ComptrollerPublicPath).borrow() 
        ?? panic(
            Error.ErrorEncode (
                msg: "Invailid comptroller cap.",
                err: Error.ErrorCode.CANNOT_ACCESS_COMPTROLLER_PUBLIC_CAPABILITY
            )
        )
    let poolAddrs = comptrollerRef.getAllMarkets()
    log(poolAddrs)
    return poolAddrs
}