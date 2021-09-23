import IncConfig from "../../contracts/IncConfig.cdc"
import IncComptrollerInterface from "../../contracts/IncComptrollerInterface.cdc"
import IncQueryInterface from "../../contracts/IncQueryInterface.cdc"

pub fun main(): IncQueryInterface.UniverseBalance {
    let comptrollerAddr: Address = IncConfig.ComptrollerAddr
    let comptrollerCap = getAccount(comptrollerAddr).getCapability <&{IncComptrollerInterface.ComptrollerPublic}> (IncConfig.Comptroller_PublicPath)
    let incInfo = comptrollerCap.borrow()!.queryUniverseBalance()
    log(incInfo)
    return incInfo
}