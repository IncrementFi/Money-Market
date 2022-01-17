import LendingInterfaces from "../../contracts/LendingInterfaces.cdc"
import Config from "../../contracts/Config.cdc"
import Error from "../../contracts/Error.cdc"

pub fun main(comptrollerAddr: Address): {Address: AnyStruct} {
    let comptrollerRef = getAccount(comptrollerAddr).getCapability<&{LendingInterfaces.ComptrollerPublic}>(Config.ComptrollerPublicPath).borrow() 
        ?? panic(
            Error.ErrorEncode (
                msg: "Invailid comptroller cap.",
                err: Error.ErrorCode.CANNOT_ACCESS_COMPTROLLER_PUBLIC_CAPABILITY
            )
        )
    let poolAddrs = comptrollerRef.getAllMarkets()

    var poolInfos: {Address: AnyStruct} = {}
    for poolAddr in poolAddrs {
        let poolInfo = comptrollerRef.getMarketInfo(poolAddr: poolAddr)
        poolInfos.insert(key: poolAddr, poolInfo)
    }
    
    return poolInfos
}