import Interfaces from "../../contracts/Interfaces.cdc"
import Config from "../../contracts/Config.cdc"



pub fun main(userAddr: Address, poolAddr: Address, comptrollerAddr: Address): {String: AnyStruct} {
    let comptrollerRef = getAccount(comptrollerAddr).getCapability<&{Interfaces.ComptrollerPublic}>(Config.ComptrollerPublicPath).borrow() ?? panic("Invailid comptroller cap.")
    let userInfo = comptrollerRef.getUserMarketInfoByAddr(userAddr: userAddr, poolAddr: poolAddr)
    
    let supplyScaled = userInfo["userSupplyScaled"] as! UInt256?!
    let borrowScaled = userInfo["userBorrowScaled"] as! UInt256?!
    log("----------------------------- query user pool info")
    log("user supply in pool: ".concat(Config.ScaledUInt256ToUFix64(supplyScaled).toString()))
    log("user borrow in pool: ".concat(Config.ScaledUInt256ToUFix64(borrowScaled).toString()))
    log("-----------------------------")
    return userInfo
}