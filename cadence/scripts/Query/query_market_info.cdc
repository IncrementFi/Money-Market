import Interfaces from "../../contracts/Interfaces.cdc"
import Config from "../../contracts/Config.cdc"

pub fun main(poolAddr: Address, comptrollerAddr: Address): {String: AnyStruct} {
    let comptrollerRef = getAccount(comptrollerAddr).getCapability<&{Interfaces.ComptrollerPublic}>(Config.ComptrollerPublicPath).borrow() ?? panic("Invailid comptroller cap.")
    let poolInfo = comptrollerRef.getMarketInfo(poolAddr: poolAddr)
    log(poolInfo)
    return poolInfo
}