import IncConfig from "../../contracts/IncConfig.cdc"
import IncComptrollerInterface from "../../contracts/IncComptrollerInterface.cdc"
import IncQueryInterface from "../../contracts/IncQueryInterface.cdc"

pub fun main(poolAddr: Address): IncQueryInterface.PoolInfo {
    let comptrollerAddr: Address = IncConfig.ComptrollerAddr
    let comptrollerCap = getAccount(comptrollerAddr).getCapability <&{IncComptrollerInterface.ComptrollerPublic}> (IncConfig.Comptroller_PublicPath)
    let poolInfo = comptrollerCap.borrow()!.queryPoolInfo(poolAddr: poolAddr)
    log(poolInfo)
    return poolInfo
}