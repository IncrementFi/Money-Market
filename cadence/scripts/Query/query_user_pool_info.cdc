import Interfaces from "../../contracts/Interfaces.cdc"
import Config from "../../contracts/Config.cdc"



pub fun main(userAddr: Address, poolAddr: Address): {String: AnyStruct} {
    let comptrollerRef = getAccount(0xf8d6e0586b0a20c7).getCapability<&{Interfaces.ComptrollerPublic}>(Config.ComptrollerPublicPath).borrow() ?? panic("Invailid comptroller cap.")
    let userInfo = comptrollerRef.getUserMarketInfoByAddr(userAddr: userAddr, poolAddr: poolAddr)
    log(userInfo)
    return userInfo
}