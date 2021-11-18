import Interfaces from "../../contracts/Interfaces.cdc"
import Config from "../../contracts/Config.cdc"



pub fun main(userAddr: Address, comptrollerAddr: Address): [Address] {
    let comptrollerRef = getAccount(comptrollerAddr).getCapability<&{Interfaces.ComptrollerPublic}>(Config.ComptrollerPublicPath).borrow() ?? panic("Invailid comptroller cap.")
    let poolAddrs = comptrollerRef.getUserMarketAddrs(userAddr: userAddr)
    log(poolAddrs)
    return poolAddrs
}