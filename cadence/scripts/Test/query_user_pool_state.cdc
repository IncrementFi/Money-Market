import Interfaces from "../../contracts/Interfaces.cdc"
import Config from "../../contracts/Config.cdc"

pub fun main(poolAddr: Address, userAddr: Address): [String;3] {
    let poolRef = getAccount(poolAddr).getCapability<&{Interfaces.PoolPublic}>(Config.PoolPublicPublicPath).borrow()!
    let res = poolRef.getAccountSnapshotScaled(account: userAddr)
    return [res[0].toString(), res[1].toString(), res[2].toString()]
}