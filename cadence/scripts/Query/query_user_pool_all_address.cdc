import Interfaces from "../../contracts/Interfaces.cdc"
import Config from "../../contracts/Config.cdc"



pub fun main(userAddr: Address): [Address] {
    let comptrollerRef = getAccount(0xf8d6e0586b0a20c7).getCapability<&{Interfaces.ComptrollerPublic}>(Config.ComptrollerPublicPath).borrow() ?? panic("Invailid comptroller cap.")
    let poolAddrs = comptrollerRef.getUserMarketAddrs(userAddr: userAddr)
    log(poolAddrs)
    return poolAddrs
}