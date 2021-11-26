import Interfaces from "../../contracts/Interfaces.cdc"
import Config from "../../contracts/Config.cdc"

pub fun main(comptrollerAddr: Address, poolAddr: Address, from: UInt64, to: UInt64): [Address] {
    let comptrollerRef = getAccount(comptrollerAddr)
        .getCapability<&{Interfaces.ComptrollerPublic}>(Config.ComptrollerPublicPath)
        .borrow() ?? panic("Invailid comptroller cap.")
    return comptrollerRef.getPoolPublicRef(poolAddr: poolAddr).getPoolBorrowerSlicedList(from: from, to: to)
}