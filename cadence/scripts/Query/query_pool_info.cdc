import Interfaces from "../../contracts/Interfaces.cdc"
import Config from "../../contracts/Config.cdc"



pub fun main(poolAddr: Address): {String: AnyStruct} {
    let comptrollerRef = getAccount(0xf8d6e0586b0a20c7).getCapability<&{Interfaces.ComptrollerPublic}>(Config.ComptrollerPublicPath).borrow() ?? panic("Invailid comptroller cap.")
    let poolInfo = comptrollerRef.getMarketInfoByAddr(poolAddr: poolAddr)
    log(poolInfo)
    return poolInfo
}