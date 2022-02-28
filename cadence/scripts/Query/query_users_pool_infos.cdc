import LendingInterfaces from "../../contracts/LendingInterfaces.cdc"
import LendingConfig from "../../contracts/LendingConfig.cdc"
import LendingError from "../../contracts/LendingError.cdc"


pub fun main(userAddrs: [Address], comptrollerAddr: Address): {Address: AnyStruct} {
    let comptrollerRef = getAccount(comptrollerAddr).getCapability<&{LendingInterfaces.ComptrollerPublic}>(LendingConfig.ComptrollerPublicPath).borrow()
        ?? panic(
            LendingError.ErrorEncode (
                msg: "Invailid comptroller cap.",
                err: LendingError.ErrorCode.CANNOT_ACCESS_COMPTROLLER_PUBLIC_CAPABILITY
            )    
        )
    var res: {Address: AnyStruct} = {}
    for userAddr in userAddrs {
        var userInfos: {Address: AnyStruct} = {}
        let poolAddrs = comptrollerRef.getUserMarkets(userAddr: userAddr)
        for poolAddr in poolAddrs {
            let userInfo = comptrollerRef.getUserMarketInfo(userAddr: userAddr, poolAddr: poolAddr)
            userInfos.insert(key: poolAddr, userInfo)
        }
        res[userAddr] = userInfos
    }
    return res
}