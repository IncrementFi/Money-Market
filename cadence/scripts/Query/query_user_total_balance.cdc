import IncConfig from "../../contracts/IncConfig.cdc"
import IncComptrollerInterface from "../../contracts/IncComptrollerInterface.cdc"
import IncQueryInterface from "../../contracts/IncQueryInterface.cdc"

pub fun main(userAddr: Address): IncQueryInterface.UserBalance {
    let comptrollerAddr: Address = IncConfig.ComptrollerAddr
    let comptrollerCap = getAccount(comptrollerAddr).getCapability <&{IncComptrollerInterface.ComptrollerPublic}> (IncConfig.Comptroller_PublicPath)
    let userBalance = comptrollerCap.borrow()!.queryUserBalance(userAddr: userAddr)
    log(userBalance)
    return userBalance
}