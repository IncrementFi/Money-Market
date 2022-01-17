import LendingInterfaces from "../../contracts/LendingInterfaces.cdc"
import LendingConfig from "../../contracts/LendingConfig.cdc"
import LendingError from "../../contracts/LendingError.cdc"

pub fun main(comptrollerAddr: Address, poolAddr: Address, from: UInt64, to: UInt64): [Address] {
    let comptrollerRef = getAccount(comptrollerAddr).getCapability<&{LendingInterfaces.ComptrollerPublic}>(LendingConfig.ComptrollerPublicPath).borrow() 
        ?? panic(
            LendingError.ErrorEncode (
                msg: "Invailid comptroller cap.",
                err: LendingError.ErrorCode.CANNOT_ACCESS_COMPTROLLER_PUBLIC_CAPABILITY
            )
        )
    if from == 0 && to == 0 {
        return comptrollerRef.getPoolPublicRef(poolAddr: poolAddr).getPoolBorrowerList()
    } else {
        return comptrollerRef.getPoolPublicRef(poolAddr: poolAddr).getPoolBorrowerSlicedList(from: from, to: to)
    }
    
}