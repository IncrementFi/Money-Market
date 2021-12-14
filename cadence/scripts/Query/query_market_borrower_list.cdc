import Interfaces from "../../contracts/Interfaces.cdc"
import Config from "../../contracts/Config.cdc"
import Error from "../../contracts/Error.cdc"

pub fun main(comptrollerAddr: Address, poolAddr: Address, from: UInt64, to: UInt64): [Address] {
    let comptrollerRef = getAccount(comptrollerAddr).getCapability<&{Interfaces.ComptrollerPublic}>(Config.ComptrollerPublicPath).borrow() 
        ?? panic(
            Error.ErrorEncode (
                msg: "Invailid comptroller cap.",
                err: Error.ErrorCode.CANNOT_ACCESS_COMPTROLLER_PUBLIC_CAPABILITY
            )
        )
    if from == 0 && to == 0 {
        return comptrollerRef.getPoolPublicRef(poolAddr: poolAddr).getPoolBorrowerList()
    } else {
        return comptrollerRef.getPoolPublicRef(poolAddr: poolAddr).getPoolBorrowerSlicedList(from: from, to: to)
    }
    
}