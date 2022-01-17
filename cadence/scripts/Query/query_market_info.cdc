import LendingInterfaces from "../../contracts/LendingInterfaces.cdc"
import LendingConfig from "../../contracts/LendingConfig.cdc"
import LendingError from "../../contracts/LendingError.cdc"

pub fun main(poolAddr: Address, comptrollerAddr: Address): {String: AnyStruct} {
    let comptrollerRef = getAccount(comptrollerAddr).getCapability<&{LendingInterfaces.ComptrollerPublic}>(LendingConfig.ComptrollerPublicPath).borrow() 
        ?? panic(
            LendingError.ErrorEncode (
                msg: "Invailid comptroller cap.",
                err: LendingError.ErrorCode.CANNOT_ACCESS_COMPTROLLER_PUBLIC_CAPABILITY
            )    
        )
    let poolInfo = comptrollerRef.getMarketInfo(poolAddr: poolAddr)
    log(poolInfo)
    return poolInfo
}