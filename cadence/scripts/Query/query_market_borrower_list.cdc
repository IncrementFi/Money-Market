import Interfaces from "../../contracts/Interfaces.cdc"
import Config from "../../contracts/Config.cdc"

pub fun main(comptrollerAddr: Address, poolAddr: Address, from: UInt64, to: UInt64): [Address] {
    let comptrollerRef = getAccount(comptrollerAddr).getCapability<&{Interfaces.ComptrollerPublic}>(Config.ComptrollerPublicPath).borrow() 
        ?? panic(
            Config.ErrorEncode (
                msg: "Invailid comptroller cap.",
                err: Config.Error.CANNOT_ACCESS_COMPTROLLER_PUBLIC_CAPABILITY
            )
        )
    return comptrollerRef.getPoolPublicRef(poolAddr: poolAddr).getPoolBorrowerSlicedList(from: from, to: to)
}